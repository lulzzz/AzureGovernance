﻿###############################################################################################################################################################
# Creates a Storage Account (e.g. felweutediag01s) in an existing Resource Group. Tags the Storage Accounts.
# Configures Firewall - allow access from all Subnets in all VNETs as well as Azure Services.
#
# Output:         $StorageAccountName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0100-StorageAccountNew -StorageAccountNameIndividual $StorageAccountNameIndividual -ResourceGroupName $ResourceGroupName `
#                                           -StorageAccountType $StorageAccountType
#                                           -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode -Contact $Contact
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0100-StorageAccountNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $StorageAccountNameIndividual = 'diagbbb',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'aaa-te-rsg-core-01',
    [Parameter(Mandatory=$false)][String] $StorageAccountType = 'standard',                                                                                      # 'standard' / 'premium'
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'te',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'                                                                                      # Tagging
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


  $StorageAccountName = InlineScript
  {
    $StorageAccountNameIndividual = $Using:StorageAccountNameIndividual
    $ResourceGroupName = $Using:ResourceGroupName
    $StorageAccountType = $Using:StorageAccountType
    $SubscriptionCode = $Using:SubscriptionCode
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $Contact = $Using:Contact 


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
    $CustomerShortCode = Get-AutomationVariable -Name VAR-AUTO-CustomerShortCode -Verbose:$false

    Write-Verbose -Message ('PAT0100-StorageAccountNameIndividual: ' + ($StorageAccountNameIndividual))
    Write-Verbose -Message ('PAT0100-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0100-StorageAccountType: ' + ($StorageAccountType))
    Write-Verbose -Message ('PAT0100-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0100-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0100-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0100-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0100-Automation: ' + ($Automation))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0100-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Storage Account name
    #
    ###########################################################################################################################################################
    $StorageAccountName = $CustomerShortCode + $RegionCode + $SubscriptionCode + $StorageAccountNameIndividual                                                   # e.g. felweutediag01s
  
    
    $StorageAccountExisting = Get-AzStorageAccount | Where-Object {$_.StorageAccountName -like "$StorageAccountName*"} `
                                                   | Sort-Object Name -Descending | Select-Object -First $True
    if ($StorageAccountExisting.Count -gt 0)                                                                                                                     # Skip if first Storage Account with this name
    {
      Write-Verbose -Message ('PAT0100-StorageAccountHighestCounter: ' + ($StorageAccountExisting.StorageAccountName))

      $Counter = 1 + ($StorageAccountExisting.StorageAccountName.SubString(($StorageAccountExisting.StorageAccountName).Length-3,2))                             # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $StorageAccountName = $StorageAccountName + $Counter1 + $StorageAccountType.Substring(0,1)                                                                 # Compile name    
    }
    else
    {
      $StorageAccountName = $StorageAccountName + '01' + $StorageAccountType.Substring(0,1)                                                                      # Compile name for first Key Vault with this name
    }
    Write-Verbose -Message ('PAT0100-StorageAccountName: ' + ($StorageAccountName)) 


    ###########################################################################################################################################################
    #
    # Check if Storage Account exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Error -Message ('PAT0100-StorageAccountExisting: ' + ($StorageAccountName))
      Return
    }
  
    try
    {
      $Result = (New-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $RegionName -Kind StorageV2 `
                                                     -SkuName ($StorageAccountType + '_LRS')).Id
      Write-Verbose -Message ('PAT0100-StorageAccountCreated: ' + ($StorageAccountName))
    }
    catch
    {
      Write-Error -Message ('PAT0100-StorageAccountNotCreated: ' + $Error[0]) 
      Return
    }


    ###########################################################################################################################################################
    #
    # Configure Firewall - allow access from all Subnets in all VNETs as well as Azure Services
    # This is currently not implemented as Azure Automation is not Trusted Microsoft service:
    # https://docs.microsoft.com/en-us/Az.Storage/common/storage-network-security#exceptions
    #
    ###########################################################################################################################################################
    <#
    # Deny access by default but allow Azure Services to bypass the Firewall
    $Result = Update-AzStorageAccountNetworkRuleSet -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -DefaultAction Deny `
                                                         -Bypass AzureServices
    Write-Verbose -Message ('PAT0100-FirewallConfigured: ' + ($Result | Out-String))

    # Allow access by all Subnets in all VNETs in the Subscription
    $Vnets = Get-AzVirtualNetwork
    foreach ($Vnet in $Vnets)
    {
      foreach ($Subnet in $Vnet.Subnets)
      {
        $Result = Add-AzStorageAccountNetworkRule -AccountName $StorageAccountName -ResourceGroupName $ResourceGroupName `
                                                       -VirtualNetworkResourceId $Subnet.Id
      }
      Write-Verbose -Message ('PAT0100-FirewallConfiguredForVnet: ' + ($Result | Out-String))
    }
    #>
  

    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0100-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzResource -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ResourceType '/Microsoft.Storage/storageAccounts' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0100-StorageAccountTagged: ' + ($StorageAccountName))


    ###########################################################################################################################################################
    #
    # Return Storage Account ID
    #
    ###########################################################################################################################################################
    Return $StorageAccountName
  }
  Return $StorageAccountName
}

