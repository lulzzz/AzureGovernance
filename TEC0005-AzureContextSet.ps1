###############################################################################################################################################################
# Setting the Azure context including the storage context for the core storage account. The context setting is attempted in an endless loop of suspend/resume 
# of this runbook.
#
# Error Handling: There is no error handling avaialble in this pattern. Errors only occur if there is a problem with the infrastructure.
#                 These types of errors are automatically logged as errors in the runbooks log. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       TEC0005-AzureContextSet
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0005-AzureContextSet
{
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Storage, Azure.Storage, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  

  # Function to set context
  Function SetContext
  {
    try
    {
      $SubscriptionName = Get-AutomationVariable -Name VAR-AUTO-SubscriptionName
      $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName
      $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser
      $Result = Disconnect-AzureRmAccount -ErrorAction SilentlyContinue
      $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
      $StorageAccount = Get-AzureRmStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
      $StorageContext = Set-AzureRmCurrentStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccount.ResourceGroupName
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
    Write-Verbose -Message ('TEC0005-ContextSettingAttemptNumber: ' + ($Counter))

    $VerbosePreference = 'SilentlyContinue'    
    $ReturnCode = SetContext
    $VerbosePreference = 'Continue'
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