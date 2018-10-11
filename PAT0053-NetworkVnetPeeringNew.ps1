###############################################################################################################################################################
# Creates a VNET peering between two VNETs. $Vnet1Name is the Shared Services VNET and $Vnet2Name is the Use Case VNET. This is important because the
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
    [Parameter(Mandatory=$false)][String] $Vnet1Name = 'weu-0005-vnt-01',                                                                                        # By default this is the Shared Services VNET
    [Parameter(Mandatory=$false)][String] $Vnet2Name = 'weu-0010-vnt-01'
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
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false

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
    # In Subscription of Vnet1 - by default this is the Shared Services VNET
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
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhBucGoWV5ZtEtsk5TTXdi3Ri
# lv2gggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
# AQUFADApMScwJQYDVQQDDB5yb2NoZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20w
# HhcNMTgwNzMxMDYyODI1WhcNMTkwNzMxMDY0ODI1WjApMScwJQYDVQQDDB5yb2No
# ZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDM1mh7YGuat1ZZq9rPnnbpP2U88qpR82M75699r1TG3Ch+v6rH
# AgDMT5d3nwiyANo968M0k3w4/B8NrG+8pe8yWM7jsKv+a8VQSgig/OiRxMmP6wOO
# qVMq52uvbPCH+Ol1uJGhgUNytZDjKxkdYW/fnd8Rnnb6GWTzFWeHsm8ugk3Uiieh
# yCL66BPzmwtNX6r4Xg+NIn5U6YNBa5+jO8v67C7YdGEBkGcyDAugSfPF1qFBRpXx
# 0gTEZd5n51TkgI1CwUL4um0Wm/ntsuEdunEypgdIhtKZu8PebHsUQpZOcOg/tPu2
# y7k+gu0PT4Mg6XiG4dMdlrgpaf/yxA9dChrpAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUUFHukpelHlbkJGU5
# +MQ1XiqrD4wwDQYJKoZIhvcNAQEFBQADggEBAERlwzGl9ufvTi1YM5cCS+s+LFvL
# 9VUkBuRKmzHaH3EqpzzRWT7apISK85PbNgP09poSVwUQZ66gV+4CcTU2EDLh86k1
# noysDZushpCVSXTStBMVtgWAz2tA96ime++3QLI0k8+bod/F65eRBedPUS5LCEbf
# bmVQAtwMRXDWdjUH3jSs2F1Pep5mcQfsZZ8uCj5P6a+dMKxLVkYmg9MoXXJqNnZM
# ANVzt5NI/ErXYOFIbPq80o/EjkfEzesB4pnDH8RdvvFHljUetFgUw0t01ZQ21/iU
# QvxWOAfVkUaLOIh0rUJNh8Xfz0vmAgWtmtRXepicK9iqSrbule5EWdMmQPwxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHnJvY2hlZ3JvdXB0ZXN0Lm9ubWljcm9zb2Z0
# LmNvbQIQVIJucZNUEZlNFZMEf+jSajAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUfRwj7QLu1kxL
# lmhFQvG9120Oq0IwDQYJKoZIhvcNAQEBBQAEggEActfhb70+NWFTMho66CzJelsn
# vwei+pSDfmOZQ7KIOgYLOlU0N/dyV4hRpghKqWGqG7B/0UL7TM+NLFrAT5xbpys+
# n+aup4WGYV+cyFKP5nuK+5efOmQl/UzaUblxp2/LipB4XUj0izQ5r0vin/enQoY5
# kFeTP64uTy/rozQHcGByzDRgtLmUeJ5lzlzFEF0brn3YWbPNPfXt/9JCXVSOX/df
# +p7oBrVtTczUQRvuHX6dIxnQKd+qiQExui/KxFIpRYlNn2S4/8WD1XrgxAQ2Vzm1
# 2xiEmyXdwMW7v22LkssG6+gz3xiLuAodXx/eREwWWlxOSA8rMWOCZ7j/b3IXKw==
# SIG # End signature block
