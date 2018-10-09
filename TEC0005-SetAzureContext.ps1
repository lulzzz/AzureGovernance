###############################################################################################################################################################
# Setting the Azure context including the storage context for the core storage account. The context setting is attempted in an endless loop of suspend/resume 
# of this runbook.
#
# Error Handling: There is no error handling avaialble in this pattern. Errors only occur if there is a problem with the infrastructure.
#                 These types of errors are automatically logged as errors in the runbooks log. 
# 
# Output:         None
#
# Requirements:   AzureAutomationAuthoringToolkit, AzureRM.profile
#
# Template:       TEC0005-SetAzureContext
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0005-SetAzureContext
{
  $VerbosePreference = 'Continue'

  # Function to set context
  Function SetContext
  {
    try
    {
      $SubscriptionName = Get-AutomationVariable -Name 'VAR-AUTO-SubscriptionName'
      $StorageAccountName = Get-AutomationVariable -Name 'VAR-AUTO-StorageAccountName'
      $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
      $AzureAccount = Add-AzureRmAccount -Credential $AzureAutomationCredential -SubscriptionName $SubscriptionName
      # $StorageAccount = Get-AzureRmStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
      # $StorageContext = Set-AzureRmCurrentStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccount.ResourceGroupName
      Return 'Success'
    }
    catch
    {
      Return 'Failure'
    }
  }

  # Perform context setting, if not successful suspend workflow and re-try after workflow is resumed
  $Counter = $null
  do
  {
    $Counter++
    Write-Verbose -Message ("TEC0005-ContextSettingAttemptNumber: $Counter")
    $ReturnCode = SetContext
    if ($ReturnCode -eq 'Failure')
    {
      Write-Error -Message ('TEC0005-SetAzureContextFailed: See error log for details')
      Suspend-Workflow
    }
    else
    {
      $AzureRmContext = Get-AzureRmContext
      Write-Verbose -Message ('TEC0005-SetAzureContext: ' + ($AzureRmContext | Out-String))
    }
  }
  until ($ReturnCode -eq 'Success')
}