param (
	[Parameter(Mandatory=$true)] $subscriptions
)

$VerbosePreference = "SilentlyContinue"

Write-Verbose "Starting child Runbook..." -Verbose

# Import Runbooks
###############################################################################
Write-Verbose "Importing Runbooks..." -Verbose
. .\ACORT-RecommendationTable.ps1
. .\ACORT-Functions.ps1

# Variables
###############################################################################
$allRecommendations = @()

$script:vmCache = @()
$script:diskCache = @()
$script:storageAccountCache = @()
$script:recoveryServicesVaultCache = @()

$billingQuery = @"
{
  "dataset": {
	  "filter": {
		"dimensions": {
			"name" : "resourceType",
			"operator" : "In",
			"values" : [
				"Microsoft.Network/publicIPAddresses",
				"Microsoft.Compute/disks",
				"Microsoft.Storage/storageAccounts",
				"Microsoft.Compute/virtualMachines",
				"Microsoft.Network/loadBalancers",
				"Microsoft.RecoveryServices/vaults",
				"Microsoft.Sql/managedInstances",
				"Microsoft.Sql/servers",
				"Microsoft.Sql/servers/databases",
				"Microsoft.Compute/snapshots"
			]
		}
	},
    "aggregation": {
		"totalCostUSD":{
			"name":"CostUSD",
			"function":"Sum"
		}
    },
    "granularity": "None",
    "grouping": [
      {
        "name": "ResourceId",
        "type": "Dimension"
      }
    ]
  },
  "timeframe": "TheLastMonth",
  "type": "AmortizedCost"
}
"@

# Authentication
###############################################################################
Write-Verbose "Authenticating..." -Verbose
try { 
	Disable-AzContextAutosave -Scope Process *>$null
    Connect-AzAccount -Identity *>$null
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Main
###############################################################################
Write-Verbose "Job has $($subscriptions.Count) subscriptions to process..." -Verbose

$subscriptions | ForEach-Object {
	Write-Verbose "Processing subscription: $($_.Name)..." -Verbose
	Set-AzContext -SubscriptionId $_.Id *>$null

	Initialize-VMCache
	Initialize-DiskCache
	Initialize-StorageAccountCache
	Initialize-RecoveryServicesVaultCache

	Add-AdvisorRecommendations -SubscriptionName $_.Name
	Add-UnattachedPublicIpRecommendations -SubscriptionName $_.Name
	Add-UnattachedManagedDiskRecommendations -SubscriptionName $_.Name
	Add-VMStoppedPowerStateRecommendations -SubscriptionName $_.Name
	Add-NonAHBWindowsVMRecommendations -SubscriptionName $_.Name
	Add-StaleVMRecommendations -SubscriptionName $_.Name
	Add-EmptyAvailabilitySetRecommendations -SubscriptionName $_.Name
	Add-UnattachedNetworkInterfaceRecommendations -SubscriptionName $_.Name
	Add-UnattachedNetworkSecurityGroupRecommendations -SubscriptionName $_.Name
	Add-EmptyLoadBalancerRecommendations -SubscriptionName $_.Name
	Add-NonAHBSqlDatabaseRecommendations -SubscriptionName $_.Name
	Add-NonAHBSqlManagedInstanceRecommendations -SubscriptionName $_.Name
	Add-V1StorageAccountRecommendations -SubscriptionName $_.Name
	Add-StorageAccountLifecycleManagementRecommendations -SubscriptionName $_.Name
	Add-NoneAHBLinuxVMRecommendations -SubscriptionName $_.Name
	Add-StaleSnapshotRecommendations -SubscriptionName $_.Name

	if($_.SubscriptionPolicies.QuotaId.Contains("DevTest")) {
		Add-DevVMNoAutoshutdownScheduleRecommendations -SubscriptionName $_.Name
		Add-DevGRSRecoveryServiceVaultsRecommendations -SubscriptionName $_.Name
		Add-DevPremiumSkuDiskRecommendations -SubscriptionName $_.Name
		Add-DevPremiumStorageAccountRecommendations -SubscriptionName $_.Name
		Add-DevStorageAccountZRSRecommendations -SubscriptionName $_.Name
		Add-DevStorageAccountGRSRecommendations -SubscriptionName $_.Name
		Add-DevStorageAccountGZRSRecommendations -SubscriptionName $_.Name
		Add-DevStorageAccountRAGRSRecommendations -SubscriptionName $_.Name
		Add-DevStorageAccountRAGZRSRecommendations -SubscriptionName $_.Name

	}

    Add-BillingData -SubscriptionId $_.Id -SubscriptionName $_.Name
	Get-SubscriptionMetadata -SubscriptionName $_.Name -SubscriptionId $_.Id
	Write-Verbose "Finished processing subscription: $($_.Name)" -Verbose
}

Write-Output -InputObject $allRecommendations
