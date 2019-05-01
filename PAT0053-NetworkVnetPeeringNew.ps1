###############################################################################################################################################################
# Creates a VNET peering between two VNETs. $Vnet1Name is the Core VNET and $Vnet2Name is the Use Case VNET. This is important because the
# Peering is configured accordingly: $Vnet1 = -AllowForwardedTraffic -AllowGatewayTransit / Vnet2 = -AllowForwardedTraffic -UseRemoteGateways
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       PAT0053-NetworkVnetPeeringNew -Vnet1Name $Vnet1Name -Vnet2Name $Vnet2Name -Gateway $Gateway
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0053-NetworkVnetPeeringNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $Vnet1Name = 'weu-co-vnt-01',                                                                                          # By default this is the Core VNET
    [Parameter(Mandatory=$false)][String] $Vnet2Name = 'weu-te-vnt-01',
    [Parameter(Mandatory=$false)][String] $Gateway = 'no'                                                                                                        # Use of Gateway in Core Subscription
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Network, Az.Accounts
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $Vnet1Name = $Using:Vnet1Name
    $Vnet2Name = $Using:Vnet2Name
    $Gateway = $Using:Gateway


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false

    # Vnet1
    $Vnet1SubscriptionCode = $Vnet1Name.Split('-')[1]
    $Vnet1SubscriptionName = (Get-AzSubscription | Where-Object {$_.Name -match $Vnet1SubscriptionCode}).Name
    $AzureAccount = Set-AzContext -Subscription $Vnet1SubscriptionName -Force
    $Vnet1 = Get-AzVirtualNetwork | Where-Object {$_.Name -eq $Vnet1Name}
    Write-Verbose -Message ('PAT0053-Vnet1: ' + ($Vnet1 | Out-String)) 

    # Vnet2
    $Vnet2SubscriptionCode = $Vnet2Name.Split('-')[1]
    $Vnet2SubscriptionName = (Get-AzSubscription | Where-Object {$_.Name -match $Vnet2SubscriptionCode}).Name
    $AzureAccount = Set-AzContext -Subscription $Vnet2SubscriptionName -Force
    $Vnet2 = Get-AzVirtualNetwork | Where-Object {$_.Name -eq $Vnet2Name}
    Write-Verbose -Message ('PAT0053-Vnet2: ' + ($Vnet2 | Out-String)) 

    # Vnet Peering Names
    $Vnet1S1, $Vnet1S2, $Vnet1S3, $Vnet1S4 = $Vnet1Name.Split('-')
    $Vnet2S1, $Vnet2S2, $Vnet2S3, $Vnet2S4 = $Vnet2Name.Split('-')
    $Vnet1NetworkPeeringName = $Vnet1S1 + '-' + $Vnet1S2 + '-per-' + $Vnet1S3 + $Vnet1S4 + '-' + $Vnet2S1 + $Vnet2S2 + $Vnet2S3 + $Vnet2S4
    $Vnet2NetworkPeeringName = $Vnet2S1 + '-' + $Vnet2S2 + '-per-' + $Vnet2S3 + $Vnet2S4 + '-' + $Vnet1S1 + $Vnet1S2 + $Vnet1S3 + $Vnet1S4
    Write-Verbose -Message ('PAT0053-Vnet1NetworkPeeringName: ' + ($Vnet1NetworkPeeringName)) 
    Write-Verbose -Message ('PAT0053-Vnet2NetworkPeeringName: ' + ($Vnet2NetworkPeeringName)) 


    ###########################################################################################################################################################
    #
    # Configure VNET Peering - check if existing 
    #
    ###########################################################################################################################################################
    # In Subscription of Vnet1 - by default this is the Core VNET
    if ($Vnet1.VirtualNetworkPeerings.Name -notcontains  $Vnet1NetworkPeeringName)
    {
      $AzureAccount = Set-AzContext -Subscription $Vnet1SubscriptionName -Force
      if ($Gateway -eq 'yes')
      {
        $Vnet1Peering = Add-AzVirtualNetworkPeering -Name $Vnet1NetworkPeeringName -VirtualNetwork $Vnet1 -RemoteVirtualNetworkId $Vnet2.Id `
                                                         -AllowForwardedTraffic -AllowGatewayTransit
      }
      else
      {
        $Vnet1Peering = Add-AzVirtualNetworkPeering -Name $Vnet1NetworkPeeringName -VirtualNetwork $Vnet1 -RemoteVirtualNetworkId $Vnet2.Id `
                                                         -AllowForwardedTraffic
      
      }
      Write-Verbose -Message ('PAT0053-Vnet1PeeringCreated: ' + ($VNet1Peering| Out-String))
    }
    else
    {
      Write-Verbose -Message ('PAT0053-Vnet1PeeringExisting: ' + ($Vnet1.VirtualNetworkPeerings | Out-String))    
    }
 
    # In Subscription of Vnet2 - by default this is the Use Case VNET
    if ($Vnet2.VirtualNetworkPeerings.Name -notcontains  $Vnet2NetworkPeeringName)
    {
      $AzureAccount = Set-AzContext -Subscription $Vnet2SubscriptionName -Force
      if ($Gateway -eq 'yes')
      {
        $Vnet2Peering = Add-AzVirtualNetworkPeering -Name $Vnet2NetworkPeeringName -VirtualNetwork $Vnet2 -RemoteVirtualNetworkId $Vnet1.Id `
                                                         -AllowForwardedTraffic -UseRemoteGateways
      }
      else
      {
        $Vnet2Peering = Add-AzVirtualNetworkPeering -Name $Vnet2NetworkPeeringName -VirtualNetwork $Vnet2 -RemoteVirtualNetworkId $Vnet1.Id `
                                                       -AllowForwardedTraffic
      }
      Write-Verbose -Message ('PAT0053-Vnet2PeeringCreated: ' + ($VNet2Peering| Out-String))
    }
    else
    {
      Write-Verbose -Message ('PAT0053-Vnet2PeeringExisting: ' + ($Vnet2.VirtualNetworkPeerings | Out-String))    
    }
  }
}

