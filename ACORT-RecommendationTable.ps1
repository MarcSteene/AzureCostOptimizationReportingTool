$recommendationTable = @{
	"UnattachedPublicIp" = @{
		RecommendationDescription = "Delete unattached Public IP address"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/architecture/framework/services/networking/ip-addresses/cost-optimization"
	}
	"UnattachedManagedDisk" = @{
		RecommendationDescription = "Delete unattached managed disk"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/disks-find-unattached-portal"
	}
	"StoppedVMState" = @{
		RecommendationDescription = "Deallocate VM in Stopped power state"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/get-started/manage-costs"
	}
	"AutoshutdownDevVM" = @{
		RecommendationDescription = "Consider enabling autoshutdown for non-production VMs to deallocate outside of working hours and on weekends"
		EstimatedSavingsRatio = 0.64
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/automation/automation-solution-vm-management"
	}
	"WindowsVMHybridBenefit" = @{
		RecommendationDescription = "Enable hybrid license benefit (AHUB) for Windows VM if you have licenses through Software Assurance"
		EstimatedSavingsRatio = 0.44
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/windows/hybrid-use-benefit-licensing"
	}
	"WindowsVMSSHybridBenefit" = @{
		RecommendationDescription = "Enable hybrid license benefit (AHUB) for Windows VM Scale Sets if you have licenses through Software Assurance"
		EstimatedSavingsRatio = 0.44
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/windows/hybrid-use-benefit-licensing"
	}
	"StaleVM" = @{
		RecommendationDescription = "Consider deleting potentially stale VM (deallocated for 90+ days) and any attached disks"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/govern/cost-management/best-practices"
	}
	"EmptyAvailabilitySet" = @{
		RecommendationDescription = "Delete empty availability set"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = $null
	}
	"UnattachedNetworkInterface" = @{
		RecommendationDescription = "Delete unattached Network Interface to free up address space"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/linux/find-unattached-nics"
	}
	"UnattachedNetworkSecurityGroup" = @{
		RecommendationDescription = "Delete unattached Network Security Group"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = $null
	}
	"EmptyLoadBalancer" = @{
		RecommendationDescription = "Delete load balancer with empty backend pool"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = $null
	}
	"GRSRecoveryServicesVaultDev" = @{
		RecommendationDescription = "Consider using locally-redundant storage (LRS) rather than geo-redundant storage (GRS) for non-production Recovery Services Vaults"
		EstimatedSavingsRatio = 0.3
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/backup/backup-create-rs-vault#modify-default-settings"
	}
	"StaleSnapshot" = @{
		RecommendationDescription = "Consider whether Snapshot created over 12 months ago is still required"
		EstimatedSavingsRatio = 1
		MicrosoftGuidance = $null
	}
	"PremiumSkuDiskDev" = @{
		RecommendationDescription = "Consider downgrading Premium disk performance tier to Standard in non-production subscriptions"
		EstimatedSavingsRatio = 0.51
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/disks-types"
	}
	"PremiumSkuStorageAccount" = @{
		RecommendationDescription = "Consider downgrading Premium Storage Account tier to Standard in non-production subscriptions"
		EstimatedSavingsRatio = 0.88
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview"
	}
	"StorageAccountZRSDev" = @{
		RecommendationDescription = "Consider downgrading non-production Storage Account from zone-redundant storage (ZRS) to locally-redundant storage (LRS)"
		EstimatedSavingsRatio = 0.11
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy"
	}
	"StorageAccountGRSDev" = @{
		RecommendationDescription = "Consider downgrading non-production Storage Account from geo-redundant storage (GRS) to locally-redundant storage (LRS)"
		EstimatedSavingsRatio = 0.45
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy"
	}
	"StorageAccountGZRSDev" = @{
		RecommendationDescription = "Consider downgrading non-production Storage Account from geo-zone-redundant storage (GZRS) to locally-redundant storage (LRS)"
		EstimatedSavingsRatio = 0.53
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy"
	}
	"StorageAccountRAGRSDev" = @{
		RecommendationDescription = "Consider downgrading non-production Storage Account from read-access geo-redundant storage (RA-GRS) to locally-redundant storage (LRS)"
		EstimatedSavingsRatio = 0.56
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy"
	}
	"StorageAccountRAGZRSDev" = @{
		RecommendationDescription = "Consider downgrading non-production Storage Account from read-access geo-zone-redundant storage (RA-GZRS) to locally-redundant storage (LRS)"
		EstimatedSavingsRatio = 0.62
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy"
	}
	"SQLDatabaseHybridBenefit" = @{
		RecommendationDescription = "Enable hybrid license benefit for SQL Database if you have licenses through Software Assurance"
		EstimatedSavingsRatio = 0.55
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/azure-sql/azure-hybrid-benefit"
	}
	"SQLManagedInstanceHybridBenefit" = @{
		RecommendationDescription = "Enable hybrid license benefit for SQL Managed Instance if you have licenses through Software Assurance"
		EstimatedSavingsRatio = 0.55
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/azure-sql/azure-hybrid-benefit"
	}
	"V1StorageAccount" = @{
		RecommendationDescription = "Upgrade General-purpose v1 Storage Account to v2. General-purpose v2 Storage Accounts support lifecycle management to optimize storage costs and lowest per-gigabyte capacity prices"
		EstimatedSavingsRatio = 0.3
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview"
	}
	"StorageAccountLifecycleManagement" = @{
		RecommendationDescription = "Optimize costs by automatically managing the data lifecycle through lifecycle management rules"
		EstimatedSavingsRatio = 0.8
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview"
	}
	"LinuxHybridBenefit" = @{
		RecommendationDescription = "Consider whether Azure Hybrid Use Benefit could be enabled for this Linux VM (SUSE Linux Enterprise Server or Red Hat Enterprise Linux images)"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/linux/azure-hybrid-benefit-linux"
	}
	"WellArchitectedFramework" = @{
		RecommendationDescription = "Review Microsoft's Well-Architected Framework Cost Optimization documentation for the latest best practices"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/architecture/framework/cost/"
	}
	"CloudAdoptionFramework" = @{
		RecommendationDescription = "Review Microsoft's Cloud Adoption Framework documentation for the latest best practices"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/get-started/manage-costs"
	}
	"DevTestOffer" = @{
		RecommendationDescription = "No subscriptions using the Dev/Test subscription offer found. Use the Dev/Test offer for your non-production subscriptions for significant discounts"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/offers/ms-azr-0148p/"
	}
	"NonDefaultLogAnalyticsRetention" = @{
		RecommendationDescription = "Review Log Analytics Workspace with a non-default (> 30 days) data retention period and consider whether this is required"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs"
	}
}