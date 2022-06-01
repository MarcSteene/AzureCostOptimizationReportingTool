$ErrorActionPreference = "Stop"

Write-Host "Reading and validating configuration file..." -ForegroundColor Yellow
Get-Content ".\config.txt" | ForEach-Object -begin { $config=@{} } -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $config.Add($k[0], $k[1]) } }

$config.Keys | ForEach-Object {
    if(!$config[$_]) {
        Write-Error "Configuration value missing for $_"
        exit
    }
}

if($config["Report Frequency"] -ne "Weekly" -and $config["Report Frequency"] -ne "Monthly") {
    Write-Error "Report frequency must be set to Weekly or Monthly. Current value: $($config["Report Frequency"])"
    exit
}

$locations = Get-AzLocation
$targetLocation = $locations | Where-Object { $_.DisplayName -eq $config["Deployment Location"] }

if(!$targetLocation) {
    $locations | ForEach-Object {
        Write-Host $_.DisplayName
    }
    Write-Host "Location $($config["Deployment Location"]) couldn't be found. Please review the above list of valid locations." -ForegroundColor Red
    exit
}

$config.Keys | ForEach-Object {
    Write-Host "$($_): $($config[$_])" -ForegroundColor Yellow
}

do {
    $confirm = Read-Host -Prompt "Please review the above configuration and ensure your account has at least the Contributor roles on the target subscription. Continue deployment? (Y/N)"

    if($confirm -eq "Y") {
        Write-Host "Beginning deployment..." -ForegroundColor Green
    }
    elseif($confirm -eq "N") {
        Write-Host "Aborting deployment" -ForegroundColor Red
        exit
    }
    else {
        Write-Host "Input not recognised, please input Y or N" -ForegroundColor Yellow
    }
}
while($confirm -ne "Y")

Write-Host "Initializing..." -ForegroundColor Yellow
$configSubscriptionName = $config["Subscription Name"]
$configResourceGroupName = $config["Resource Group Name"]
$configLogicAppName = $config["Logic App Name"]
$configAutomationAccountName = $config["Automation Account Name"]
$configDeploymentLocation = $config["Deployment Location"]
$configReportFrequency = $config["Report Frequency"]
$configMailRecipients = $config["Mail Recipients"]

Write-Host "[1/18] Checking for valid subscription: $configSubscriptionName" -ForegroundColor Yellow
$subscriptions = Get-AzSubscription
$deploymentSubscription = $subscriptions | Where-Object { $_.Name -eq $configSubscriptionName }

if(!$deploymentSubscription) {
    Write-Host "Subscription with name $configSubscriptionName couldn't be found. Verify the configured name is spelled correctly and that the current user has (Contributor and User Access Administrator) OR (Owner) role(s) on the target subscription. Accessible susbcriptions: " -ForegroundColor Red
    $subscriptions | Select-Object -Property Name
    exit
}

Write-Host "[2/18] Subscription identified. Setting context." -ForegroundColor Green
Set-AzContext -SubscriptionName $deploymentSubscription.Name

Write-Host "[3/18] Creating resource group..." -ForegroundColor Yellow
New-AzResourceGroup -Name $configResourceGroupName -Location $configDeploymentLocation -Force

Write-Host "[4/18] Deploying API Connection..." -ForegroundColor Yellow
$apiId = "subscriptions/$($deploymentSubscription.Id)/providers/Microsoft.Web/locations/$($targetLocation.Location)/managedApis/office365"
$apiConnection = New-AzResource -Properties @{ `
    "api" = @{ `
        "id" = $apiId}; `
        "displayName" = "office365"; `
     } `
     -ResourceName "office365" `
     -ResourceType "Microsoft.Web/connections" `
     -ResourceGroupName $configResourceGroupName `
     -Location $configDeploymentLocation `
     -Force

$tempParametersFileName = ".\LogicAppParameters-$(Get-Random).json"

(Get-Content -path .\LogicAppParameters.json) | ForEach-Object {
    $_ -replace '!!ConnectionId',$apiConnection.ResourceId `
       -replace '!!ApiId',$apiId
}  | Set-Content -Path $tempParametersFileName

Write-Host "[5/18] Deploying Logic App..." -ForegroundColor Yellow
$tempDefinitionFileName = ".\LogicAppDefinition-$(Get-Random).json"
((Get-Content -path .\LogicAppDefinition.json) -replace '!!MailRecipients',$configMailRecipients) | Set-Content -Path $tempDefinitionFileName

New-AzLogicApp -ResourceGroupName $configResourceGroupName `
                -Location $configDeploymentLocation `
                -Name $configLogicAppName `
                -DefinitionFilePath $tempDefinitionFileName `
                -ParameterFilePath  $tempParametersFileName

Remove-Item -Path $tempDefinitionFileName
Remove-Item -Path $tempParametersFileName

Write-Host "[6/18] Creating automation account..." -ForegroundColor Yellow
New-AzAutomationAccount -Name $configAutomationAccountName `
                        -ResourceGroupName $configResourceGroupName `
                        -Location $configDeploymentLocation

Write-Host "[7/18] Registering modules on automation account..." -ForegroundColor Yellow
$module = Find-Module az.MonitoringSolutions
New-AzAutomationModule -AutomationAccountName $configAutomationAccountName -ResourceGroupName $configResourceGroupName -Name $module.Name -ContentLinkUri "$($module.RepositorySourceLocation)/package/$($module.Name)/$($module.Version)"                        

Write-Host "[8/18] Enabling Managed Identity on Automation Account..." -ForegroundColor Yellow
Set-AzAutomationAccount -Name $configAutomationAccountName `
                        -ResourceGroupName $configResourceGroupName `
                        -AssignSystemIdentity

Write-Host "[9/18] Deploying Automation Schedules..." -ForegroundColor Yellow
$StartTime = (Get-Date "08:00:00").AddDays(1)
$monday = [System.DayOfWeek]::Monday
New-AzAutomationSchedule -AutomationAccountName $configAutomationAccountName -Name "WeeklySchedule" -StartTime $StartTime -WeekInterval 1 -DaysOfWeek $monday -ResourceGroupName $configResourceGroupName
New-AzAutomationSchedule -AutomationAccountName $configAutomationAccountName -Name "MonthlySchedule" -StartTime $StartTime -MonthInterval 1 -DaysOfMonth "Five" -ResourceGroupName $configResourceGroupName

Write-Host "[10/18] Deploying runbooks (1/4)..." -ForegroundColor Yellow
$postUri = (Get-AzLogicAppTriggerCallbackUrl -ResourceGroupName $configResourceGroupName -Name $configLogicAppName -TriggerName "manual").Value
$random = Get-Random
(Get-Content -path .\ACORT-Main.ps1) | ForEach-Object {
    $_ -replace '!!LogicAppEndpoint',$postUri `
       -replace '!!AutomationAccountName',$configAutomationAccountName `
       -replace '!!ResourceGroupName',$configResourceGroupName
}  | Set-Content -Path ".\ACORT-Main-$random.ps1"
Import-AzAutomationRunbook -Path ".\ACORT-Main-$random.ps1" -Name "ACORT-Main" -Type "PowerShell" -LogVerbose $true -AutomationAccountName $configAutomationAccountName -ResourceGroupName $configResourceGroupName -Published -Force
Write-Host "[11/18] Deploying runbooks (2/4)..." -ForegroundColor Yellow
Import-AzAutomationRunbook -Path ".\ACORT-ProcessSubscriptions.ps1" -Name "ACORT-ProcessSubscriptions" -Type "PowerShell" -LogVerbose $true -AutomationAccountName $configAutomationAccountName -ResourceGroupName $configResourceGroupName -Published -Force
Write-Host "[12/18] Deploying runbooks (3/4)..." -ForegroundColor Yellow
Import-AzAutomationRunbook -Path ".\ACORT-Functions.ps1" -Name "ACORT-Functions" -Type "PowerShell" -LogVerbose $true -AutomationAccountName $configAutomationAccountName -ResourceGroupName $configResourceGroupName -Published -Force
Write-Host "[13/18] Deploying runbooks (4/4)..." -ForegroundColor Yellow
Import-AzAutomationRunbook -Path ".\ACORT-RecommendationTable.ps1" -Name "ACORT-RecommendationTable" -Type "PowerShell" -LogVerbose $true -AutomationAccountName $configAutomationAccountName -ResourceGroupName $configResourceGroupName -Published -Force

Write-Host "[14/18] Deleting temporary runbook file..." -ForegroundColor Yellow
Remove-Item -Path ".\ACORT-Main-$random.ps1"

Write-Host "[15/18] Assigning schedule to main runbook..." -ForegroundColor Yellow
if($configReportFrequency -eq "Weekly") {
    Register-AzAutomationScheduledRunbook -AutomationAccountName $configAutomationAccountName -Name "ACORT-Main" -ScheduleName "WeeklySchedule" -ResourceGroupName $configResourceGroupName
}
else {
    Register-AzAutomationScheduledRunbook -AutomationAccountName $configAutomationAccountName -Name "ACORT-Main" -ScheduleName "MonthlySchedule" -ResourceGroupName $configResourceGroupName
}

Write-Host "[16/18] Assigning Managed Identity 'Automation Job Operator' role on Automation Account..." -ForegroundColor Yellow
$automationAccount = Get-AzResource -Name $configAutomationAccountName -ResourceGroupName $configResourceGroupName
New-AzRoleAssignment -ObjectId $automationAccount.Identity.PrincipalId -RoleDefinitionName "Automation Job Operator" -Scope $automationAccount.ResourceId

Write-Host "[17/18] Assigning Managed Identity 'Automation Runbook Operator' role on Automation Account..." -ForegroundColor Yellow
New-AzRoleAssignment -ObjectId $automationAccount.Identity.PrincipalId -RoleDefinitionName "Automation Runbook Operator" -Scope $automationAccount.ResourceId

Write-Host "[18/18] Deployment complete. Additional configuration steps are required, see the documentation for details. Press any key to continue."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
