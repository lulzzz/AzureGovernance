###############################################################################################################################################################
# This runbook is used for testing purposes. Use this runbook to trigger the PATxxx type runbooks.
# 
# Error Handling: n/a 
# 
# Output:         n/a
#
# Requirements:   n/a
#
# Template:       None
#
# Change log:
# 0.1             Initial version
#
###############################################################################################################################################################
workflow SOL9999-ForPatternTesting
{
  $VerbosePreference = 'Continue'

  ###########################################################################################################################################################
  # 
  # Parameters
  # 
  ###########################################################################################################################################################



  ###########################################################################################################################################################
  # 
  # Insert runbook to be executed 
  # 
  ###########################################################################################################################################################
  # TEC0005-SetAzureContext
  
  $VerbosePreference = 'Continue'



  Return
}

<#
###########################################################################################################################################################
# 
# Below is not part of the runbook. This allows to query the latest job that was updated in Azure Automation. Output is in grid for better sorting.
# 
###########################################################################################################################################################

###########################################################################################################################################################
# Get latest job (last modified)
###########################################################################################################################################################
GetLatestJob
Function GetLatestJob 
{
  $JobData = Get-AzureRmAutomationJob -AutomationAccountName ams-te-auto-dev-01 -ResourceGroupName ams-te-rg-core-01 | 
  Sort-Object -Property LastModifiedTime | Select-Object -Last 1 | 
  Get-AzureRmAutomationJobOutput |
  Where-Object -FilterScript {($_.Summary -like '*PAT0*') -or ($_.Summary -like '*SOL0*') -or ($_.Summary -like '*TEC0*') -or ($_.Type -eq 'Error') -or ($_.Type -eq 'Warning')} |
  Get-AzureRmAutomationJobOutputRecord
  $NumberOfEntities = $JobData.count
  $Counter = 0
  $Output = do
  {
      if ($JobData.Type[$Counter] -eq 'Verbose')
      {
        [PSCustomObject]@{DateTime = $JobData[$Counter].Time.DateTime;
                          MessageType =  $JobData[$Counter].Type;
                          Message = (($JobData[$Counter].Value.Message) -split 'localhost]\:')[1]}
      }
      else
      {
        [PSCustomObject]@{DateTime = $JobData[$Counter].Time.DateTime;
                          MessageType =  $JobData[$Counter].Type;
                          Message = $JobData[$Counter].Value.Exception.Message}
      }
      $Counter = $Counter+1
  }
  until ($Counter -ge $NumberOfEntities)
  $Output | Out-GridView
}


###########################################################################################################################################################
# Get specific job in CB
###########################################################################################################################################################
$JobId = '6d88fcfb-beef-4e69-bb40-b7b91fe4088f'
$JobData = Get-AzureRmAutomationJob -Id $JobId -AutomationAccountName ams-te-auto-dev-01 -ResourceGroupName ams-te-rg-core-01 | 
Get-AzureRmAutomationJobOutput |
Where-Object -FilterScript {($_.Summary -like '*PAT0*') -or ($_.Summary -like '*SOL0*') -or ($_.Summary -like '*TEC0*') -or ($_.Type -eq 'Error') -or ($_.Type -eq 'Warning')} |
Get-AzureRmAutomationJobOutputRecord
$NumberOfEntities = $JobData.count
$Counter = 0
$Output = do
{
    if ($JobData.Type[$Counter] -eq 'Verbose')
    {
      [PSCustomObject]@{DateTime = $JobData[$Counter].Time.DateTime;
                        MessageType =  $JobData[$Counter].Type;
                        Message = (($JobData[$Counter].Value.Message) -split 'localhost]\:')[1]}
    }
    else
    {
      [PSCustomObject]@{DateTime = $JobData[$Counter].Time.DateTime;
                        MessageType =  $JobData[$Counter].Type;
                        Message = $JobData[$Counter].Value.Exception.Message}
    }
    $Counter = $Counter+1
}
until ($Counter -ge $NumberOfEntities)
$Output | Out-GridView

 
###########################################################################################################################################################
# 
# Import Runbook into Azure Automation using PowerShell
# 
###########################################################################################################################################################
$AutomationAccountName = 'ams-te-auto-dev-01'
$RgName = 'ams-te-rg-core-01'
$LocalDirectoryName = 'D:\Documents\WindowsPowerShell\....'
$PowerShellWorkflowName = 'PAT0001-CreateNetworkInterface.ps1'

$AutomationAccount = Get-AzureRmAutomationAccount -Name $AutomationAccountName -ResourceGroupName $RgName

Import-AzureRmAutomationRunbook -ResourceGroupName $RgName -AutomationAccountName $AutomationAccount.AutomationAccountName `
                                -Type PowerShellWorkflow `
                                -Path ($LocalDirectoryName + $PowerShellWorkflowName) `
                                -LogVerbose $true `
                                -Published `
                                -Description 'Imported using PowerShell' `
                                -Force
#>