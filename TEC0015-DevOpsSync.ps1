###############################################################################################################################################################
# Executes a synch of the Azure Automation account with the DevOps Repository that is configured on the Azure Automation Account. 
# This Runook is used if Auto-Sync has been disable and the synchronization is triggered via a Release Pipeline in Azure DevOps - or other tool. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below 
#
# Template:       TEC0015-DevOpsSync
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0015-DevOpsSync
{
  [OutputType([object])] 	

  param
  (
     
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Automation, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $GitHubRepo = $Using:GitHubRepo


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AutomationAccountName = Get-AutomationVariable -Name VAR-AUTO-AutomationAccountName -Verbose:$false
    $ResourceGroupName = (Get-AzResource | Where-Object {$_.Name -eq $AutomationAccountName}).ResourceGroupName

    Write-Verbose -Message ('TEC0004-CoreResourceGroup: ' + ($ResourceGroupName))
    Write-Verbose -Message ('TEC0004-AutomationAccountName: ' + ($AutomationAccountName))


    ###########################################################################################################################################################
    #
    # Start the synch job
    #
    ###########################################################################################################################################################
    $AutomationAccount = Get-AzAutomationAccount -Name $AutomationAccountName -ResourceGroupName $ResourceGroupName 
    $AutomationSourceControl = Get-AzAutomationSourceControl -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName

    $SyncJob = Start-AzAutomationSourceControlSyncJob -SourceControlName $AutomationSourceControl.Name -AutomationAccountName $AutomationAccountName `
                                                      -ResourceGroupName $ResourceGroupName
  }
}

