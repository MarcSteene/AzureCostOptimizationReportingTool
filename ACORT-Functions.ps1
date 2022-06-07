$VerbosePreference = "SilentlyContinue"

# Functions
###############################################################################

function ConvertTo-Object($hashtable) 
{
	if($hashtable) {
		$object = New-Object PSObject
		$hashtable.GetEnumerator() | 
		ForEach-Object {
			Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value 
		}
		return $object
	}
}

function Add-Recommendation {
	Param (
		[parameter(Mandatory=$true)][String]
		$subscriptionName,
		[parameter(Mandatory=$true)][String]
		$resourceId,
		[parameter(Mandatory=$true)][String]
		$resourceName,
		[parameter(Mandatory=$true)][String]
		$resourceGroupName,
		[parameter(Mandatory=$true)][string]
		$recommendationType
	)

	$script:allRecommendations += [pscustomobject]@{
		OutputType = "Recommendation"
		SubscriptionName = $subscriptionName
		Recommendation = $recommendationTable[$recommendationType].RecommendationDescription
		ResourceId = $resourceId
		ResourceName = $resourceName
		ResourceGroup = $resourceGroupName
		CostLastMonth = "No billing data"
		EstimatedSavingsRatio = $recommendationTable[$recommendationType].EstimatedSavingsRatio
		EstimatedMonthlySavings = "No estimate"
		Currency = $null
		MicrosoftGuidance = $recommendationTable[$recommendationType].MicrosoftGuidance
	}
}

function Initialize-VMCache {
	Write-Verbose "Building Virtual Machine cache..." -Verbose

	$script:vmCache = Get-AzVM -Status
}

function Initialize-DiskCache {
	Write-Verbose "Building Managed Disk cache..." -Verbose

	$script:diskCache = Get-AzDisk
}

function Initialize-StorageAccountCache {
	Write-Verbose "Building Storage Account cache..." -Verbose

	$script:storageAccountCache = Get-AzStorageAccount
}

function Initialize-RecoveryServicesVaultCache {
	Write-Verbose "Building Recovery Services Vault cache..." -Verbose

	$script:recoveryServicesVaultCache = Get-AzRecoveryServicesVault
}

function Initialize-LogAnalyticsWorkspaceCache {
	Write-Verbose "Building Log Analytics Workspace cache..." -Verbose

	$script:logAnalyticsWorkspaceCache = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -notlike "DefaultWorkspace-*" }
}

function Add-BillingData {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionId,
		[parameter(Mandatory=$true)]
		[String] $subscriptionName
    )

	Write-Verbose "Getting subscription billing data..." -Verbose

	$billingData = @()
	$targetUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/query?api-version=2021-10-01"

	do {
		Write-Verbose "Processing billing data page..." -Verbose
		$response = (Invoke-AzRestMethod -Uri $targetUri -Method Post -Payload $billingQuery).Content | ConvertFrom-JSON
		$billingData += $response.properties.rows
		$targetUri = $response.properties.nextLink
	}
	while ($response.properties.nextLink)

	Write-Verbose "Applying billing data to recommendations..." -Verbose
	
	foreach($resource in $billingData) {
		for($i = 0; $i -lt $allRecommendations.Count; $i++) {
			if($allRecommendations[$i].ResourceId -eq $resource[1]) {
					$script:allRecommendations[$i].CostLastMonth = $resource[0].ToString()
					$script:allRecommendations[$i].Currency = "USD"
					if($allRecommendations[$i].EstimatedSavingsRatio) {
						$script:allRecommendations[$i].EstimatedMonthlySavings = ($allRecommendations[$i].EstimatedSavingsRatio * $resource[0]).ToString()
					}
			}
		}
	}
}

function Add-UnattachedPublicIpRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for unattached Public IP Addresses..." -Verbose

	Get-AzPublicIpAddress `
	| Where-Object { $_.IpConfiguration -eq $null } `
	| ForEach-Object { `
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "UnattachedPublicIp"
	}
}

function Add-NonDefaultLogAnalyticsWorkspaceRetentionPeriodRecommendations {
	Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Log Analytics Workspaces with billable data retention period (>30 days)..." -Verbose

	$logAnalyticsWorkspaceCache `
	| Where-Object { $_.retentionInDays -gt 31 } `
	| ForEach-Object {
		$workspaceName = $_.Name
		$sentinelEnabled = Get-AzMonitorLogAnalyticsSolution | Where-Object { $_.Name -eq "SecurityInsights($workspaceName)"  }
		if(!$sentinelEnabled) {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.ResourceId `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "NonDefaultLogAnalyticsRetention"
		}
	}
}

function Add-NonDefaultSentinelWorkspaceRetentionPeriodRecommendations {
	Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Sentinel Workspaces with billable data retention period (>90 days)..." -Verbose

	$logAnalyticsWorkspaceCache | Where-Object { $_.retentionInDays -gt 90 } `
	| ForEach-Object {
		$workspaceName = $_.Name
		$sentinelEnabled = Get-AzMonitorLogAnalyticsSolution | Where-Object { $_.Name -eq "SecurityInsights($workspaceName)"  }
		if($sentinelEnabled) {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.ResourceId `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "NonDefaultSentinelWorkspaceRetention"
		}
	}
}

function Add-LogAnalyticsWorkspaceCommitmentTierRecommendations {
	    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking Log Analytics Workspaces for commitment tier right-size..." -Verbose

	$query = @'
		Usage
		| where TimeGenerated > ago(31d) and TimeGenerated < ago(1d)
		| where IsBillable == True
		| summarize TotalGBytes =round(sum(Quantity/(1024)),2) by bin(TimeGenerated, 1d)
		| summarize ['gbperday'] =round(avg(TotalGBytes),2)
'@

	$logAnalyticsWorkspaceCache | ForEach-Object {
		$averageDailyIngestion = (Invoke-AzOperationalInsightsQuery -WorkspaceId $_.CustomerId -Query $query -Wait 120 | Select-Object Results).Results.gbperday

		if($averageDailyIngestion -ne "NaN") {
			if($_.Sku.contains("pergb")) {
				if($averageDailyIngestion -gt 5000) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier5000GB"
				}
				elseif($averageDailyIngestion -gt 2000) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier2000GB"
				}			
				elseif($averageDailyIngestion -gt 1000) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier1000GB"
				}
				elseif($averageDailyIngestion -gt 500) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier500GB"
				}			
				elseif($averageDailyIngestion -gt 400) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier400GB"
				}			
				elseif($averageDailyIngestion -gt 300) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier300GB"
				}
				elseif($averageDailyIngestion -gt 200) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier200GB"
				}
				elseif($averageDailyIngestion -gt 100) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "LogAnalyticsWorkspaceCommitmentTier100GB"
				}
			} elseif($_.CapacityReservationLevel -gt 0 -and ($_.CapacityReservationLevel + 100) -lt $averageDailyIngestion) {
				Add-Recommendation `
				-SubscriptionName $subscriptionName `
				-ResourceId $_.ResourceId `
				-ResourceName $_.Name `
				-ResourceGroupName $_.ResourceGroupName `
				-RecommendationType "LogAnalyticsWorkspaceCommitmentTierIncrease"
			} elseif($_.CapacityReservationLevel -gt 0 -and $_.CapacityReservationLevel -gt ($averageDailyIngestion + 100)) {
				Add-Recommendation `
				-SubscriptionName $subscriptionName `
				-ResourceId $_.ResourceId `
				-ResourceName $_.Name `
				-ResourceGroupName $_.ResourceGroupName `
				-RecommendationType "LogAnalyticsWorkspaceCommitmentTierDecrease"
			}
		}
	}
}

function Add-SentinelWorkspaceCommitmentTierRecommendations {
	    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking Sentinel Workspaces for commitment tier right-size......" -Verbose

	$query = @'
		Usage
		| where TimeGenerated > ago(31d) and TimeGenerated < ago(1d)
		| where IsBillable == True
		| summarize TotalGBytes =round(sum(Quantity/(1024)),2) by bin(TimeGenerated, 1d)
		| summarize ['gbperday'] =round(avg(TotalGBytes),2)
'@

	$logAnalyticsWorkspaceCache	| ForEach-Object {
		$workspaceName = $_.Name
		$sentinelEnabled = Get-AzMonitorLogAnalyticsSolution | Where-Object { $_.Name -eq "SecurityInsights($workspaceName)"  }
		
		if($sentinelEnabled) {
			$averageDailyIngestion = (Invoke-AzOperationalInsightsQuery -WorkspaceId $_.CustomerId -Query $query -Wait 120 | Select-Object Results).Results.gbperday

			if($averageDailyIngestion -ne "NaN") {
				if($_.Sku.contains("pergb")) {
					if($averageDailyIngestion -gt 5000) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier5000GB"
					}
					elseif($averageDailyIngestion -gt 2000) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier2000GB"
					}			
					elseif($averageDailyIngestion -gt 1000) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier1000GB"
					}
					elseif($averageDailyIngestion -gt 500) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier500GB"
					}			
					elseif($averageDailyIngestion -gt 400) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier400GB"
					}			
					elseif($averageDailyIngestion -gt 300) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier300GB"
					}
					elseif($averageDailyIngestion -gt 200) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier200GB"
					}
					elseif($averageDailyIngestion -gt 100) {
						Add-Recommendation `
						-SubscriptionName $subscriptionName `
						-ResourceId $_.ResourceId `
						-ResourceName $_.Name `
						-ResourceGroupName $_.ResourceGroupName `
						-RecommendationType "SentinelWorkspaceCommitmentTier100GB"
					}
				} elseif($_.CapacityReservationLevel -gt 0 -and ($_.CapacityReservationLevel + 100) -lt $averageDailyIngestion) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $_.ResourceId `
					-ResourceName $_.Name `
					-ResourceGroupName $_.ResourceGroupName `
					-RecommendationType "SentinelWorkspaceCommitmentTierIncrease"
				} elseif($_.CapacityReservationLevel -gt 0 -and $_.CapacityReservationLevel -gt ($averageDailyIngestion + 100)) {
				Add-Recommendation `
				-SubscriptionName $subscriptionName `
				-ResourceId $_.ResourceId `
				-ResourceName $_.Name `
				-ResourceGroupName $_.ResourceGroupName `
				-RecommendationType "SentinelWorkspaceCommitmentTierDecrease"
			}
			}
		}
	}
}

function Add-LogAnalyticsWorkspacePerNodeTierRecommendations {
	Param(
		[parameter(Mandatory=$true)]
		[String] $subscriptionName 
    )
	Write-Verbose "Checking for Log Analytics Workspaces with legacy Per-Node pricing tier..." -Verbose

	$logAnalyticsWorkspaceCache | Where-Object { $_.sku -eq "pernode" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.ResourceId `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "LogAnalyticsPerNodePricingTier"
	}
}

function Add-UnattachedManagedDiskRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for unattached Managed Disks..." -Verbose

    $diskCache `
	| Where-Object { $_.DiskState -eq "Unattached" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "UnattachedManagedDisk"
	}
}

function Add-VMStoppedPowerStateRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for VMs in 'Stopped' power state..." -Verbose

	$vmCache `
	| Where-Object { $_.PowerState -eq "VM stopped" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StoppedVMState"
	}
}

function Add-DevVMNoAutoshutdownScheduleRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for VMs in Dev/Test subscriptions with no autoshutdown schedule enabled..." -Verbose

	$vmCache `
	| ForEach-Object {
		$scheduleId = $_.Id.Replace("Microsoft.Compute/virtualMachines/","microsoft.devtestlab/schedules/shutdown-computevm-") + $_.Name
		$schedule = Get-AzResource -ResourceId $scheduleId 2>$null
		if(!$schedule -or $schedule.properties.Status -eq "Disabled") {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.Id `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "AutoshutdownDevVM"
		}
	}
}

function Add-NonAHBWindowsVMRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Windows VMs without Azure Hybrid Benefit enabled..." -Verbose

	$vmCache `
	| Where-Object { !$_.LicenseType -and $_.StorageProfile.OsDisk.OsType -eq "Windows"} `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "WindowsVMHybridBenefit"
	}
}

function Add-NonAHBWindowsVMSSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Windows VM Scale Sets without Azure Hybrid Benefit enabled..." -Verbose

	Get-AzVmss `
	| Where-Object { !$_.VirtualMachineProfile.LicenseType -and $_.VirtualMachineProfile.OsProfile.WindowsConfiguration } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "WindowsVMSSHybridBenefit"
	}
}

function Add-StaleVMRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for VMs deallocated for over 90 days..." -Verbose

	$vmCache `
	| Where-Object { $_.PowerState -eq "VM deallocated" } `
	| ForEach-Object {
		$logs = Get-AzActivityLog -ResourceId $_.Id -StartTime (Get-Date).AddDays(-90) `
		| Where-Object { $_.OperationName.Value -eq "Microsoft.Compute/virtualMachines/deallocate/action" }

		if(!$logs) {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.Id `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "StaleVM"

			$vmId = $_.Id
			$osDiskName = $_.StorageProfile.OsDisk.Name
			$osDisk = $diskCache | Where-Object { $_.Name -eq $osDiskName -and $_.ManagedBy -eq $_.Id }

			# Unmanaged disks won't be included in the disk cache so need to null check
			if($osDisk) {
				Add-Recommendation `
				-SubscriptionName $subscriptionName `
				-ResourceId $osDisk.Id `
				-ResourceName $osDisk.Name `
				-ResourceGroupName $osDisk.ResourceGroupName `
				-RecommendationType "StaleVM"
			}

			$_.StorageProfile.DataDisks | ForEach-Object {
				$diskName = $_.Name
				$disk = $diskCache | Where-Object { $_.Name -eq $diskName -and $_.ManagedBy -eq $vmId }
				if($disk) {
					Add-Recommendation `
					-SubscriptionName $subscriptionName `
					-ResourceId $disk.Id `
					-ResourceName $disk.Name `
					-ResourceGroupName $disk.ResourceGroupName `
					-RecommendationType "StaleVM"
				}
			}
		}
	}
}

function Add-EmptyAvailabilitySetRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for empty Availability Sets..." -Verbose

	Get-AzAvailabilitySet `
	| Where-Object { !$_.VirtualMachinesReferences } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "EmptyAvailabilitySet"
	}
}

function Add-UnattachedNetworkInterfaceRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for unattached Network Interfaces..." -Verbose

	Get-AzNetworkInterface `
	| Where-Object { !$_.VirtualMachine } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "UnattachedNetworkInterface"
	}
}

function Add-UnattachedNetworkSecurityGroupRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for unattached Network Security Groups..." -Verbose

	Get-AzNetworkSecurityGroup `
	| Where-Object { !$_.NetworkInterfaces -and !$_.Subnets } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "UnattachedNetworkSecurityGroup"
	}
}

function Add-EmptyLoadBalancerRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for empty Load Balancers..." -Verbose

	Get-AzLoadBalancer `
	| Where-Object { !$_.BackendAddressPools } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "EmptyLoadBalancer"
	}
}

function Add-DevGRSRecoveryServiceVaultsRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for GRS Recovery Services Vaults in Dev/Test Subscriptions..." -Verbose

	if(!$recoveryServicesVaultCache) { return }

	$recoveryServicesVaultCache `
	| ForEach-Object {
		$backupProperty = Get-AzRecoveryServicesBackupProperty -Vault $_
		if($backupProperty.BackupStorageRedundancy -eq "GeoRedundant") {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.Id `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "GRSRecoveryServicesVaultDev"
		}
	}
}

function Add-StaleSnapshotRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Snapshots over 12 months old..." -Verbose

	Get-AzSnapshot `
	| Where-Object { $_.TimeCreated -lt ((Get-Date).AddDays(-365)) } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StaleSnapshot"
	}
}

function Add-DevPremiumSkuDiskRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Premium SKU Managed Disks in Dev/Test Subscriptions..." -Verbose

	$diskCache `
	| Where-Object { $_.Sku.Tier -eq "Premium" } `
	| ForEach-Object {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.Id `
			-ResourceName $_.Name `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "PremiumSkuDiskDev"
	}
}

function Add-DevPremiumStorageAccountRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Premium SKU Storage Accounts in Dev/Test Subscriptions..." -Verbose

	$storageAccountCache `
	| Where-Object { $_.Sku.Tier -eq "Premium" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "PremiumSkuStorageAccount"
	}
}

function Add-DevStorageAccountZRSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Storage Accounts with ZRS replication in Dev/Test Subscriptions..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Sku.Name.Split("_")[1] -eq "ZRS" } `
	| ForEach-Object { 
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StorageAccountZRSDev"
	}
}

function Add-DevStorageAccountGRSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Storage Accounts with GRS replication in Dev/Test Subscriptions..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Sku.Name.Split("_")[1] -eq "GRS" } `
	| ForEach-Object { 
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StorageAccountGRSDev"
	}
}

function Add-DevStorageAccountGZRSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Storage Accounts with GZRS replication in Dev/Test Subscriptions..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Sku.Name.Split("_")[1] -eq "GZRS" } `
	| ForEach-Object { 
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StorageAccountGZRSDev"
	}
}

function Add-DevStorageAccountRAGRSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Storage Accounts with RA-GRS replication in Dev/Test Subscriptions..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Sku.Name.Split("_")[1] -eq "RAGRS" } `
	| ForEach-Object { 
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StorageAccountRAGRSDev"
	}
}

function Add-DevStorageAccountRAGZRSRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Storage Accounts with RA-GZRS replication in Dev/Test Subscriptions..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Sku.Name.Split("_")[1] -eq "RAGZRS" } `
	| ForEach-Object { 
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "StorageAccountRAGZRSDev"
	}
}

function Add-NonAHBSqlDatabaseRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for SQL Databases without Azure Hybrid Benefit enabled..." -Verbose

	Get-AzSqlServer `
	| ForEach-Object {
		Get-AzSqlDatabase -ServerName $_.ServerName -ResourceGroupName $_.ResourceGroupName `
		| ForEach-Object {
			if($_.DatabaseName -ne "master" -and $_.LicenseType -eq "LicenseIncluded") {
				Add-Recommendation `
				-SubscriptionName $subscriptionName `
				-ResourceId $_.ResourceId `
				-ResourceName $_.DatabaseName `
				-ResourceGroupName $_.ResourceGroupName `
				-RecommendationType "SQLDatabaseHybridBenefit"
			}
		}
	}
}

function Add-NonAHBSqlManagedInstanceRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for SQL Managed Instances without Azure Hybrid Benefit enabled..." -Verbose

	Get-AzSqlInstance `
	| Where-Object { $_.LicenseType -eq "LicenseIncluded" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "SQLManagedInstanceHybridBenefit"
	}
}

function Add-V1StorageAccountRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for V1 Storage Accounts..." -Verbose
	
	$storageAccountCache `
	| Where-Object { $_.Kind -eq "Storage" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.StorageAccountName `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "V1StorageAccount"
	}
}

function Add-StorageAccountLifecycleManagementRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for V2 Storage Accounts with no lifecycle management policy..." -Verbose

	$storageAccountCache `
	| Where-Object { $_.Kind -ne "Storage" } `
	| ForEach-Object {
		$policy = Get-AzStorageAccountManagementPolicy -StorageAccountResourceId $_.Id 2>$null

		if(!$policy) {
			Add-Recommendation `
			-SubscriptionName $subscriptionName `
			-ResourceId $_.Id `
			-ResourceName $_.StorageAccountName `
			-ResourceGroupName $_.ResourceGroupName `
			-RecommendationType "StorageAccountLifecycleManagement"
		}
	}
}

function Add-NoneAHBRHELVMRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for Red Hat Enterprise Linux VMs without Hybrid Benefit enabled..." -Verbose

	$vmCache `
	| Where-Object { $_.StorageProfile.ImageReference.Publisher -eq "RedHat" -and $_.LicenseType -ne "RHEL_BYOS" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "RHELHybridBenefit"
	}
}

function Add-NoneAHBSLESVMRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Checking for SUSE Linux Enterprise Server VMs without Hybrid Benefit enabled..." -Verbose

	$vmCache `
	| Where-Object { $_.StorageProfile.ImageReference.Publisher -eq "SUSE" -and $_.LicenseType -ne "SLES_BYOS" } `
	| ForEach-Object {
		Add-Recommendation `
		-SubscriptionName $subscriptionName `
		-ResourceId $_.Id `
		-ResourceName $_.Name `
		-ResourceGroupName $_.ResourceGroupName `
		-RecommendationType "SLESHybridBenefit"
	}
}

function Add-AdvisorRecommendations {
    Param(
        [parameter(Mandatory=$true)]
        [String] $subscriptionName 
    )
	Write-Verbose "Adding Azure Advisor recommendations..." -Verbose

	$advisorRecommendations = Get-AzAdvisorRecommendation -Category Cost

	Write-Verbose "Found $($advisorRecommendations.Count) Advisor recommendations" -Verbose

	foreach($item in $advisorRecommendations) {
		if($item.ExtendedProperties.annualSavingsAmount) {
			$monthlySavings = ($item.ExtendedProperties.annualSavingsAmount / 12).ToString()
		}
		else {
			$monthlySavings = "No estimate"
		}

		if($item.ImpactedField -eq "Microsoft.Subscriptions/subscriptions") {
			$script:allRecommendations += [pscustomobject]@{
				OutputType = "Recommendation"
				SubscriptionName = $subscriptionName
				Recommendation = $item.ShortDescription.Problem
				ResourceId = $item.ResourceMetadata.ResourceId
				ResourceName = $subscriptionName
				ResourceGroup = "NA"
				CostLastMonth = "No billing data"
				EstimatedSavingsRatio = $null
				EstimatedMonthlySavings = $monthlySavings
				Currency = $item.ExtendedProperties.savingsCurrency
				MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/advisor/advisor-overview"
			}
		}
		else {
			$resourceIdSplit = $item.ResourceId.Split("/")
			$resourceGroupName = "NA"

			for($i = 0; $i -lt $resourceIdSplit.Count; $i++) {
				if($resourceIdSplit[$i] -eq "resourceGroups"){
					$resourceGroupName = $resourceIdSplit[($i+1)]
				}
			}
			
			$script:allRecommendations += [pscustomobject]@{
				OutputType = "Recommendation"
				SubscriptionName = $subscriptionName
				Recommendation = $item.ShortDescription.Problem
				ResourceId = $item.ResourceId
				ResourceName = $item.ImpactedValue
				ResourceGroup = $resourceGroupName
				CostLastMonth = "No billing data"
				EstimatedSavingsRatio = $null
				EstimatedMonthlySavings = $monthlySavings
				Currency = $item.ExtendedProperties.savingsCurrency
				MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/advisor/advisor-overview"
			}
		}
	}
}

function Add-WACOAIPRecommendation {
	Write-Verbose "Adding Microsoft IP recommendation..." -Verbose

	Add-Recommendation `
	-SubscriptionName "Global" `
	-ResourceId "NA" `
	-ResourceName "NA" `
	-ResourceGroupName "NA" `
	-RecommendationType "WACOAIP"
}

function Add-WAFRecommendation {
	Write-Verbose "Adding Well-Architected Framework recommendation..." -Verbose

	Add-Recommendation `
	-SubscriptionName "Global" `
	-ResourceId "NA" `
	-ResourceName "NA" `
	-ResourceGroupName "NA" `
	-RecommendationType "WellArchitectedFramework"
}

function Add-CAFRecommendation {
	Write-Verbose "Adding Cloud Adoption Framework recommendation..." -Verbose
	
	Add-Recommendation `
	-SubscriptionName "Global" `
	-ResourceId "NA" `
	-ResourceName "NA" `
	-ResourceGroupName "NA" `
	-RecommendationType "CloudAdoptionFramework"
}

function Add-DevTestRecommendation {
	Param(
		[parameter(Mandatory=$true)]
		$subscriptions
	)
	Write-Verbose "Checking for Dev/Test Subscription offer usage..." -Verbose

	$devTestSubscriptions = $subscriptions | Where-Object { $_.SubscriptionPolicies.QuotaId.Contains("DevTest") }

	if(!$devTestSubscriptions) {
		Add-Recommendation `
		-SubscriptionName "Global" `
		-ResourceId "NA" `
		-ResourceName "NA" `
		-ResourceGroupName "NA" `
		-RecommendationType "DevTestOffer"
	}
	else {
		Write-Verbose "Found $($devTestSubscriptions.Count) subscriptions using Dev/Test offer" -Verbose
	}
}

function Get-SubscriptionMetadata {
	Param(
		[parameter(Mandatory=$true)]
		[String] $subscriptionName,
		[parameter(Mandatory=$true)]
		[String] $subscriptionId
	)
	Write-Verbose "Getting subscription metadata..." -Verbose

    $azToken = $(Get-AzAccessToken).Token
    $headers = @{
        'Content-Type'='application/json'
        'Authorization' = "Bearer $($azToken)"
    }

	$costManagementUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/query?api-version=2021-10-01"

    $query = @"
    {
        "type":"AmortizedCost",
        "dataSet":{
            "granularity":"None",
            "aggregation":{
                "totalCostUSD":{
                    "name":"CostUSD",
                    "function":"Sum"
                }
            }
        },
        "timeframe":"TheLastMonth"
    }
"@

	$response = Invoke-RestMethod -Uri $costManagementUri -Method Post -Body $query -Headers $headers

	if($response.properties.rows) {
		$costLastMonthUSD = $response.properties.rows[0][0]
		$costLastMonthUSD = [math]::Round($costLastMonthUSD,2)
	}
	else {
		$costLastMonthUSD = "No billing data available"
	}

	$totalRecommendationCount = 0
	$estimatedMonthlySavings = @{}

	$allRecommendations `
	| Where-Object { $_.SubscriptionName -eq $subscriptionName } `
	| ForEach-Object {
		$totalRecommendationCount++
		if($_.EstimatedMonthlySavings -ne "No estimate") {
			if($estimatedMonthlySavings[$_.Currency]) {
				$estimatedMonthlySavings[$_.Currency] += [decimal]$_.EstimatedMonthlySavings
			}
			else {
				$estimatedMonthlySavings[$_.Currency] = [decimal]$_.EstimatedMonthlySavings
			}
		}
	}

	if($costLastMonthUSD -eq "No billing data available" -or $costLastMonthUSD -eq 0) {
		$subscriptionEfficiency = "No billing data available"
	}
	else {
		$subscriptionEfficiency = (($costLastMonthUSD - $estimatedMonthlySavings["USD"]) / $costLastMonthUSD).ToString("P")
	}

	$metadata = [pscustomobject]@{
		OutputType = "SubscriptionMetadata"
		SubscriptionName = $subscriptionName
		TotalRecommendationCount = $totalRecommendationCount
		CostLastMonthUSD = $costLastMonthUSD
	}

	$estimatedMonthlySavings.Keys `
	| ForEach-Object {
		$roundedValue = [math]::Round($estimatedMonthlySavings[$_],2)
		$metadata | Add-Member -MemberType NoteProperty -Name ("EstimatedMonthlySavings$_") -Value $roundedValue
	}

	$metadata | Add-Member -MemberType NoteProperty -Name ("SubscriptionEfficiency") -Value $subscriptionEfficiency

	Write-Output -InputObject $metadata
}
