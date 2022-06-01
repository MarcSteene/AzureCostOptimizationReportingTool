$VerbosePreference = "SilentlyContinue"

Write-Verbose "Starting..." -Verbose

# Import Runbooks
###############################################################################
Write-Verbose "Importing Runbooks..."
. .\ACORT-RecommendationTable.ps1
. .\ACORT-Functions.ps1

# Variables
###############################################################################
$logicAppUri = "!!LogicAppEndpoint"
$allRecommendations = @()
$maxJobs = 5

# Authentication
###############################################################################
Write-Verbose "Authenticating..." -Verbose
try {
	# Ensure that the runbook does not inherit an AzContext
	Disable-AzContextAutosave -Scope Process *>$null
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Main
###############################################################################
Write-Verbose "Getting subscriptions with Read access..." -Verbose
$subscriptions = Get-AzSubscription

Write-Verbose "Found $($subscriptions.Count) subscriptions:" -Verbose
$subscriptions | ForEach-Object {
	Write-Verbose "$($_.Name) - $($_.Id)" -Verbose
}

Add-WACOAIPRecommendation
Add-WAFRecommendation
Add-CAFRecommendation
Add-DevTestRecommendation -Subscriptions $subscriptions

$roundRobin = @{}
$i = 0

foreach($subscription in $subscriptions) {
	if($i -eq $maxJobs) {
		$i = 0
	}

	if($roundRobin[$i]) {
		$roundRobin[$i] += $subscription
	}
	else {
		$roundRobin[$i] = @($subscription)
	}
	$i++
}

Write-Verbose "Starting child jobs..." -Verbose
$childJobs = @()
$jobStatus = @{}
$childOutput = @()

$roundRobin.Keys | ForEach-Object {
	$params = @{ "subscriptions"=$roundRobin[$_] }
	
	$job = Start-AzAutomationRunbook `
        -AutomationAccountName "!!AutomationAccountName" `
        -ResourceGroupName "!!ResourceGroupName" `
        -Name "ACORT-ProcessSubscriptions" `
		-Parameters $params

	$childJobs += $job
	$jobStatus[$job.JobId] = $false
}

Write-Verbose "Waiting for child jobs to complete..." -Verbose
do {
	Start-Sleep -s 5
	$runningJobs = 0
	$childJobs | ForEach-Object {
		$job = Get-AzAutomationJob `
        -AutomationAccountName "!!AutomationAccountName" `
        -ResourceGroupName "!!ResourceGroupName" `
		-Id $_.JobId
		
		if($job.Status -eq "Failed") {
			Write-Error ("Child job failed: " + $_.JobId)
			throw
		}
		elseif($job.Status -eq "Stopped") {
			Write-Error ("Child job stopped: " + $_.JobId)
			throw
		}
		elseif($job.Status -eq "Completed" -and !$jobStatus[$job.JobId]) {
			Write-Verbose ("Retrieving child job output: " + $job.JobId) -Verbose
			$jobStatus[$job.JobId] = $true
			$childOutput += (Get-AzAutomationJobOutput `
            -AutomationAccountName "!!AutomationAccountName" `
            -ResourceGroupName "!!ResourceGroupName" `
			-Id $job.JobId `
			-Stream "Output" | Get-AzAutomationJobOutputRecord).Value
		}
		elseif($job.Status -ne "Completed") {
			$runningJobs++
		}
	}	
} while($runningJobs -gt 0)
Write-Verbose "All child jobs completed" -Verbose

$subscriptionMetadata = @()

$childOutput | Where-Object { $_.OutputType -eq "SubscriptionMetadata" } | ForEach-Object {
	$subscriptionMetadata += ConvertTo-Object($_)
}

$subscriptionMetadata = $subscriptionMetadata | Sort-Object -Property TotalRecommendationCount -Descending

$childOutput | Where-Object { $_.OutputType -eq "Recommendation" } | ForEach-Object {
	$script:allRecommendations += ConvertTo-Object($_)
}

Write-Verbose "Generating summary CSV..." -Verbose
$summaryCsv = (($subscriptionMetadata `
	| Select-Object -Property SubscriptionName, TotalRecommendationCount, CostLastMonthUSD, * -ExcludeProperty OutputType 2>$null `
	| ConvertTo-CSV -NoTypeInformation) -join [Environment]::NewLine)

Write-Verbose "Generating report CSV..." -Verbose
$reportCsv = ($allRecommendations `
	| Select-Object -Property * -ExcludeProperty EstimatedSavingsRatio, OutputType `
	| ConvertTo-CSV -NoTypeInformation) -join [Environment]::NewLine

$totalEstimatedMonthlySavings = 0
$script:allRecommendations | ForEach-Object {
	if($_.EstimatedMonthlySavings -ne "No estimate") {
		$totalEstimatedMonthlySavings += $_.EstimatedMonthlySavings
	}
}

$totalEstimatedMonthlySavings = [math]::Round($totalEstimatedMonthlySavings,2)

$payload = [pscustomobject]@{
	ReportCSV = $reportCsv
	SummaryCSV = $summaryCsv
	SubscriptionCount = $subscriptions.Count
	RecommendationCount = $allRecommendations.Count
	EstimatedMonthlySavings = "$totalEstimatedMonthlySavings USD"
} | ConvertTo-Json

Write-Verbose "Posting data to Logic App..." -Verbose
Invoke-RestMethod -Uri $logicAppUri -Method Post -Body $payload -ContentType "application/json"

Write-Verbose "Complete" -Verbose