###############################################################################################################################################################
# Imports an individual Runbook from GitHub into Azure Automation. 
# This Runbook needs to be executed from the Automation Account to which the Runbooks are imported. 
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
    [Parameter(Mandatory=$false)][String] $RunbookName = 'TEC0005-AzureContextSet.ps1'
  )
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Automation
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


    ###########################################################################################################################################################
    #  
    # Import to Azure Automation
    #  
    ###########################################################################################################################################################
    $RgName = 'weu-co-rsg-automation-01'
    $AutomationAccountName = Get-AutomationVariable -Name 'VAR-AUTO-AutomationAccountName'
    $Result = Import-AzureRmAutomationRunbook -ResourceGroupName $RgName `
                                    -AutomationAccountName $AutomationAccountName `
                                    -Type PowerShellWorkflow `
                                    -Path D:\$RunbookName `
                                    -LogVerbose $true `
                                    -Published `
                                    -Description 'Imported from GitHub' `
                                    -Force
  }
}
