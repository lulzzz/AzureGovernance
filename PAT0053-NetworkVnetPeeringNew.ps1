###############################################################################################################################################################
# Creates a VNET peering between two VNETs. $Vnet1Name is the Core VNET and $Vnet2Name is the Use Case VNET. This is important because the
# Peering is configured accordingly: $Vnet1 = -AllowForwardedTraffic -AllowGatewayTransit / Vnet2 = -AllowForwardedTraffic -UseRemoteGateways
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       PAT0053-NetworkVnetPeeringNew -Vnet1Name $Vnet1Name -Vnet2Name $Vnet2Name
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0053-NetworkVnetPeeringNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $Vnet1Name = 'weu-co-vnt-01',                                                                                          # By default this is the Core VNET
    [Parameter(Mandatory=$false)][String] $Vnet2Name = 'weu-te-vnt-01'
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Network, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $Vnet1Name = $Using:Vnet1Name
    $Vnet2Name = $Using:Vnet2Name


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false

    # Vnet1
    $Vnet1SubscriptionName = $Vnet1Name.Split('-')[1]
    $Vnet1SubscriptionName = (Get-AzureRmSubscription | Where-Object {$_.Name -match ('_S' + $Vnet1SubscriptionName + '_')}).Name
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet1SubscriptionName -Force
    $Vnet1 = Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $Vnet1Name}
    Write-Verbose -Message ('PAT0053-Vnet1: ' + ($Vnet1 | Out-String)) 

    # Vnet2
    $Vnet2SubscriptionName = $Vnet2Name.Split('-')[1]
    $Vnet2SubscriptionName = (Get-AzureRmSubscription | Where-Object {$_.Name -match ('_S' + $Vnet2SubscriptionName + '_')}).Name
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet2SubscriptionName -Force
    $Vnet2 = Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $Vnet2Name}
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
      $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet1SubscriptionName -Force
      $Vnet1Peering = Add-AzureRmVirtualNetworkPeering -Name $Vnet1NetworkPeeringName -VirtualNetwork $Vnet1 -RemoteVirtualNetworkId $Vnet2.Id `
                                                       -AllowForwardedTraffic -AllowGatewayTransit
      Write-Verbose -Message ('PAT0053-Vnet1PeeringCreated: ' + ($VNet1Peering| Out-String))
    }
    else
    {
      Write-Verbose -Message ('PAT0053-Vnet1PeeringExisting: ' + ($Vnet1.VirtualNetworkPeerings | Out-String))    
    }
 
    # In Subscription of Vnet2 - by default this is the Use Case VNET
    if ($Vnet2.VirtualNetworkPeerings.Name -notcontains  $Vnet2NetworkPeeringName)
    {
      $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet2SubscriptionName -Force
      $Vnet2Peering = Add-AzureRmVirtualNetworkPeering -Name $Vnet2NetworkPeeringName -VirtualNetwork $Vnet2 -RemoteVirtualNetworkId $Vnet1.Id `
                                                       -AllowForwardedTraffic -UseRemoteGateways
      Write-Verbose -Message ('PAT0053-Vnet2PeeringCreated: ' + ($VNet2Peering| Out-String))
    }
    else
    {
      Write-Verbose -Message ('PAT0053-Vnet2PeeringExisting: ' + ($Vnet2.VirtualNetworkPeerings | Out-String))    
    }
  }
}