###############################################################################################################################################################
# Setting the Azure context including the storage context for the core storage account. The context setting is attempted in an endless loop of suspend/resume 
# of this runbook.
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
    $Result = Import-Module Az.Storage, Az.Storage, Az.Accounts
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
      $Result = DisConnect-AzAccount -ErrorAction SilentlyContinue
      $AzureAccount = Connect-AzAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
      $StorageAccount = Get-AzStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
      $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.StorageAccountName).Value[0]
      try
      {
        
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
      }
      catch
      {
        # No catch - try/catch used to supress error messages in case the Core Storage Account is not (yet) available.
      }
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
      $AzContext = Get-AzContext
      Write-Verbose -Message ('TEC0005-SetAzureContext: ' + ($AzContext | Out-String))
    }
  }
  until ($ReturnCode -eq 'Success')
}
