<#
	Azure Cost Optimization Reporting Tool
	Version: v1.02
	Module: ACORT-RecommendationTable.ps1
	Author: Marc Steene
#>

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
	"RHELHybridBenefit" = @{
		RecommendationDescription = "Enable Hybrid Benefit for Red Hat Enterprise Linux VMs if appropriately licensed"
		EstimatedSavingsRatio = 0.25
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/virtual-machines/linux/azure-hybrid-benefit-linux"
	}
	"SLESHybridBenefit" = @{
		RecommendationDescription = "Enable Hybrid Benefit for SUSE Linux Enterprise Server VMs if appropriately licensed"
		EstimatedSavingsRatio = 0.05
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
	"WACOAIP" = @{
		RecommendationDescription = "Consider the Microsoft Well-Architected Cost Optimization Assessment and Implementation IP to work with an accredited Microsoft engineer to optimize your Azure resources"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "Contact your Customer Success Account Manager (CSAM) for details"
	}
	"DevTestOffer" = @{
		RecommendationDescription = "No subscriptions using the Dev/Test subscription offer found. Use the Dev/Test offer for your non-production subscriptions for significant discounts"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/offers/ms-azr-0148p/"
	}
	"NonDefaultLogAnalyticsRetention" = @{
		RecommendationDescription = "Review Log Analytics Workspace with a data retention period configured above the free threshold (31 days) and consider whether this is required"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs"
	}
	"NonDefaultSentinelWorkspaceRetention" = @{
		RecommendationDescription = "Review Sentinel workspace with a data retention period configured above the free threshold (90 days) and consider whether this is required"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-us/azure/sentinel/billing?tabs=commitment-tier#analytics-logs"
	}
	"LogAnalyticsPerNodePricingTier" = @{
		RecommendationDescription = "Use the Microsoft-provided query to determine whether it would be cheaper to remain on the Per-Node pricing tier or change to Pay-as-you-go"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://docs.microsoft.com/en-gb/azure/azure-monitor/logs/cost-logs#evaluate-the-legacy-per-node-pricing-tier"
	}
	"SentinelWorkspaceCommitmentTierPAYG" = @{
		RecommendationDescription = "Considering changing Sentinel workspace from a commitment tier to pay-as-you-go pricing to save money based on current ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier100" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 100GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier200" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 200GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier300" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 300GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier400" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 400GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier500" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 500GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier1000" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 1000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier2000" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 2000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"SentinelWorkspaceCommitmentTier5000" = @{
		RecommendationDescription = "Considering changing Sentinel workspace tier to 5000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/microsoft-sentinel/"
	}
	"LogAnalyticsWorkspaceCommitmentTierPAYG" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace from a commitment tier to pay-as-you-go pricing to save money based on current ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier100" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 100GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier200" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 200GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier300" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 300GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier400" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 400GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier500" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 500GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier1000" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 1000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier2000" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 2000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
	"LogAnalyticsWorkspaceCommitmentTier5000" = @{
		RecommendationDescription = "Considering changing Log Analytics workspace tier to 5000GB commitment tier to save money based on ingestion"
		EstimatedSavingsRatio = $null
		MicrosoftGuidance = "https://azure.microsoft.com/en-gb/pricing/details/monitor/#purchase-options"
	}
}