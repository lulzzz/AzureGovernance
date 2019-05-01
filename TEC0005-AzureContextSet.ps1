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
# 2.0             Migration to Az modules with use of Service Principal
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
      $TenantId = Get-AutomationVariable -Name VAR-AUTO-TenantId
      $Result = Disconnect-AzAccount -ErrorAction SilentlyContinue
      $AzureAccount = Connect-AzAccount -ServicePrincipal -Credential $AzureAutomationCredential -TenantId $TenantId -ErrorAction Stop
      $AzContext = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop
      try
      {
        $StorageAccount = Get-AzStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
        $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.StorageAccountName).Value[0]
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
      }
      catch
      {
        # No catch - try/catch used to supress error messages in case the Core Storage Account is not (yet) available.
      }
      Return $StorageContext
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
      Write-Verbose -Message ('TEC0005-AzureContext: ' + (Get-AzContext | Out-String))
      Write-Verbose -Message ('TEC0005-StorageContext: ' + ($ReturnCode | Out-String))
    }
  }
  while ($ReturnCode -eq 'Failure')
}


