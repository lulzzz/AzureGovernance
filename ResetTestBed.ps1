###############################################################################################################################################################
# Resets the test bed used for testing the Solutions
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       ResetTestBed -SubscriptionCode $SubscriptionCode
#                                                     
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow ResetTestBed
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'Development-de'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  
  ###########################################################################################################################################################
  #
  # Parameters
  #
  ###########################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false


  ###########################################################################################################################################################
  #
  # Change to Target Subscription
  #
  ###########################################################################################################################################################
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
  Write-Verbose -Message ('ResetTestBed-TargetSubscription: ' + ($Subscription | Out-String))
  $Result = Disconnect-AzureRmAccount
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('ResetTestBed-AzureContextChanged: ' + ($AzureContext | Out-String))


  ###########################################################################################################################################################
  #
  # Remove Resources created by SOL0001
  #
  ###########################################################################################################################################################
  $ResourceGroups = @()
  $ResourceGroups = 'neu-de-rsg-core-01','neu-de-rsg-network-01','neu-de-rsg-security-01', `
                    'weu-de-rsg-core-01','weu-de-rsg-network-01','weu-de-rsg-security-01'
  foreach -parallel ($ResourceGroup in $ResourceGroups)
  {
    Remove-AzureRmResourceGroup $ResourceGroup -Force
  }
  
  Remove-AzureRmPolicyAssignment -Id '/subscriptions/2ed9306c-a0ac-4231-bc8d-f74e3cb54bde/providers/Microsoft.Authorization/policyAssignments/Allowed locations'


  ###########################################################################################################################################################
  #
  # Reset Azure Table Ipam in the Core Storage Account
  #
  ###########################################################################################################################################################
  TEC0005-AzureContextSet
  InlineScript
  {
    # Update all entries
    $Table = Get-AzureStorageTable -Name Ipam
    $TableEntries = Get-AzureStorageTableRowAll -table $Table 
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = ''
      $TableEntry.SubnetName = ''
      $TableEntry | Update-AzureStorageTableRow -table $Table
    }
  }
}
