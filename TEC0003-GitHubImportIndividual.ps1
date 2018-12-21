###############################################################################################################################################################
# Used to import an individual Runbook from GitHub into the Azure Automation Account in which TEC0003 is executed. 
# The import overwrite existing Runbooks in the Azure Automation Account.
# Runbooks are imported with verbose logging on, a description 'Imported from GitHub' and in a published state.
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       TEC0003-GitHubImportIndividual -GitHubRepo $GitHubRepo -RunbookName $RunbookName
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0003-GitHubImportIndividual
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $GitHubRepo = '/fbodmer/AzureGovernance',
    [Parameter(Mandatory=$false)][String] $RunbookName = 'PAT0300-MonitoringWorkspaceNew.ps1'
  )
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Automation, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  InlineScript
  {
    $GitHubRepo = $Using:GitHubRepo 
    $RunbookName = $Using:RunbookName


    ###########################################################################################################################################################
    #  
    # Download Runbook from GitHub
    #  
    ###########################################################################################################################################################
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $RunbookGitHub = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents/$RunbookName" -UseBasicParsing
    $RunbookContent = $RunbookGitHub.Content | ConvertFrom-Json
    $RunbookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::` 
                      FromBase64String($RunbookContent.content))
    $Result = Out-File -InputObject $RunbookContent -FilePath D:\$RunbookName -Force
    Write-Verbose -Message ('TEC0003-RunbookDownloadedFromGit: ' + ($RunbookContent | Out-String))


    ###########################################################################################################################################################
    #  
    # Import to Azure Automation
    #  
    ###########################################################################################################################################################
    $AutomationAccountName = Get-AutomationVariable -Name VAR-AUTO-AutomationAccountName
    $ResourceGroupName = (Get-AzureRmResource | Where-Object {$_.Name -eq $AutomationAccountName}).ResourceGroupName
    $Result = Import-AzureRmAutomationRunbook -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AutomationAccountName `
                                              -Type PowerShellWorkflow `
                                              -Path D:\$RunbookName `
                                              -LogVerbose $true `
                                              -Published `
                                              -Description 'Imported from GitHub' `
                                              -Force

    Write-Verbose -Message ('TEC0003-RunbookImportedToAzureAutomation: ' + ($RunbookContent | Out-String))
  }
}