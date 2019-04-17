###############################################################################################################################################################
# Updates an NSG by applying the selected rule set retrieved from CSV on Files on core Storage Account.  
#
# Output:         'Success', 'Failure'
#
# Requirements:   See Import-Module in code below / Must run on Hybrid Worker due to usage of C:\Windows\Temp\
#
# Template:       PAT0058-NetworkSecurityGroupSet -NsgName $NsgName -SubscriptionCode $SubscriptionCode -RuleSetName $RuleSetName
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0058-NetworkSecurityGroupSet
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $NsgName = 'weu-co-nsg-vnt01fe',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'co',
    [Parameter(Mandatory=$false)][String] $RuleSetName = 'default'
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Network, Az.Accounts, Az.Resources, AzTable
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $Result = InlineScript
  { 
    $NsgName = $Using:NsgName
    $SubscriptionCode = $Using:SubscriptionCode
    $RuleSetName = $Using:RuleSetName


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
    
    Write-Verbose -Message ('PAT0058-NsgName: ' + ($NsgName))    
    Write-Verbose -Message ('PAT0058-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0058-RuleSetName: ' + ($RuleSetName))


    ###########################################################################################################################################################
    #
    # Get Rule Set - must occur prior to context switch to target Subscription
    #
    ###########################################################################################################################################################
    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName -Verbose:$false
    $StorageAccount = Get-AzResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccountName
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey.Value[0] 
    $Result = Get-AzStorageFileContent -Context $StorageContext -ShareName nsg-rule-set -Path NsgRuleSets.csv -Destination D:\ -Force -Verbose:$false
    $NsgRuleSets = Import-Csv -Path  D:\NsgRuleSets.csv 
    $NsgRuleSet = $NsgRuleSets | Where-Object {$_.RuleSet -match $RuleSetName}
    Write-Verbose -Message ('PAT0058-RulesToApply: ' + ($NsgRuleSet | Out-String))
 

    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = DisConnect-AzAccount
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0058-AzureContextChanged: ' + ($AzureContext | Out-String))

    
    ###########################################################################################################################################################
    #  
    # Check that NSG exists
    #
    ###########################################################################################################################################################
    $Nsg = Get-AzResource | Where-Object {$_.name -eq $NsgName}
    $ResourceGroupName = $Nsg.ResourceGroupName                                                                                                                  # e.g. weu-te-rsg-network-01
    $Nsg = Get-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $ResourceGroupName                                                                  # Get-AzResource not retrieving all parameters
    Write-Verbose -Message ('PAT0058-Nsg: ' + ($Nsg | Out-String))

    if ($ResourceGroupName.Length -le '0')
    {
      Write-Error -Message ('PAT0058-NsgNotExisting: ' + ($NsgName))
      Return 'Failure'
    }


    ###########################################################################################################################################################
    #  
    # Retrieve IP ranges of Subnets used in NSG Rules
    #
    ###########################################################################################################################################################
    $VnetName = ($Nsg.Subnets[0].Id).Split('/')[8]
    $ResourceGroupNameVnet = ($Nsg.Subnets[0].Id).Split('/')[4]
    $Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupNameVnet
    Write-Verbose -Message ('PAT0058-Vnet: ' + ($Vnet)) 

    $FrontendSubnetAddressPrefix = ($Vnet.Subnets | Where-Object {$_.Name -match '-fe'}).AddressPrefix
    Write-Verbose -Message ('PAT0058-FrontendSubnetAddressPrefix: ' + ($FrontendSubnetAddressPrefix)) 

    $BackendSubnetAddressPrefix = ($Vnet.Subnets | Where-Object {$_.Name -match '-be'}).AddressPrefix
    Write-Verbose -Message ('PAT0058-BackendSubnetAddressPrefix: ' + ($BackendSubnetAddressPrefix)) 

    # Get the Address Prefix of the Subnet that is connected to the NSG
    $NsgSubnetAddressPrefix = ($Vnet.Subnets | Where-Object {$_.Name -eq ($Nsg.Subnets[0].Id).Split('/')[10]}).AddressPrefix
    Write-Verbose -Message ('PAT0058-NsgSubnetAddressPrefix: ' + ($NsgSubnetAddressPrefix))


    ###########################################################################################################################################################
    #  
    # Retrieve and update Rule Set for NSG
    #
    ###########################################################################################################################################################
    # Update placeholders in Rule Set - resolve placeholders such as '$FrontendSubnetAddressPrefix' to actual value such as '10.155.18.32/27'
    foreach ($Rule in $NsgRuleSet)
    {
      if ($Rule.SourceAddressPrefix -eq '$FrontendSubnetAddressPrefix') {$Rule.SourceAddressPrefix = $FrontendSubnetAddressPrefix}
      if ($Rule.SourceAddressPrefix -eq '$BackendSubnetAddressPrefix') {$Rule.SourceAddressPrefix = $BackendSubnetAddressPrefix}
      if ($Rule.DestinationAddressPrefix -eq '$FrontendSubnetAddressPrefix') {$Rule.DestinationAddressPrefix = $FrontendSubnetAddressPrefix}
      if ($Rule.DestinationAddressPrefix -eq '$BackendSubnetAddressPrefix') {$Rule.DestinationAddressPrefix = $BackendSubnetAddressPrefix}
    }
    Write-Verbose -Message ('PAT0058-UpdatedRulesToApply: ' + ($NsgRuleSet | Out-String))


    ###########################################################################################################################################################
    #  
    # Apply Rules
    #
    ###########################################################################################################################################################
    foreach ($Rule in $NsgRuleSet)
    {
      $Result = Remove-AzNetworkSecurityRuleConfig -Name $Rule.Name -NetworkSecurityGroup $Nsg                                                              # Remove existing rule before re-creating it
      
      # Only apply rule if the IP ranges are not the same as the one of Subnet to which they should be applied
      if ($NsgSubnetAddressPrefix -ne $Rule.SourceAddressPrefix -and $NsgSubnetAddressPrefix -ne $Rule.DestinationAddressPrefix) 
      {
        $Result = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg `
                                                       -Name $Rule.Name `
                                                       -Description $Rule.Description `
                                                       -Protocol $Rule.Protocol `
                                                       -SourcePortRange $Rule.SourcePortRange `
                                                       -DestinationPortRange $Rule.DestinationPortRange `
                                                       -SourceAddressPrefix $Rule.SourceAddressPrefix `
                                                       -DestinationAddressPrefix $Rule.DestinationAddressPrefix `
                                                       -Access $Rule.Access `
                                                       -Priority $Rule.Priority `
                                                       -Direction $Rule.Direction
        $Result = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $Nsg
        Write-Verbose -Message ('PAT0058-SecurityRuleApplied: ' + ($Rule.Name))
      }
    }
    Return 'Success'
  }
  Return $Result
}
