###############################################################################################################################################################
# Providing access to Internet for the standard VNET in a Use Case Subscription.
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#                
#
# Template:       SOL0053-NetworkUcToInternetNew -SubscriptionName $SubscriptionName -Region $Region
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow SOL0053-NetworkUcToInternetNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionName = 'RT_S0010_ RECF_SND0010',                                                                          # Hosting VNET to be connected
    [Parameter(Mandatory=$false)][String] $UseCaseVnetName = 'weu-0010-vnt-01'                                                                                                # Hosting VNET to be connected
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


  #############################################################################################################################################################
  #
  # Parameters 
  #
  #############################################################################################################################################################
  $SharedServicesSubscriptionName = (Get-AzureRmContext).Subscription.Name
  $LoadBalancerIpAddress = '10.155.12.38'
  $Regioncode = $UseCaseVnetName.Split('-')[0]
  $SubscriptionCode = ($SubscriptionName.Split('_')[1]).Substring(1,4)
  $SharedServicesVnetName = $RegionCode + '-' + '0005' + '-vnt-01'
  $UseCaseVnetName = $RegionCode + '-' + $SubscriptionCode + '-vnt-01'  
  $ResourceGroupNameUseCaseVnet = $RegionCode + '-' + $SubscriptionCode + '-rsg-network-01'                                                                      # e.g. weu-0010-rsg-network-01

  Write-Verbose -Message ('SOL0053-SubscriptionName: ' + ($SubscriptionName))
  Write-Verbose -Message ('SOL0053-RegionCode: ' + ($RegionCode))
  Write-Verbose -Message ('SOL0053-SubscriptionCode: ' + ($SubscriptionCode))
  Write-Verbose -Message ('SOL0053-SharedServicesVnetName: ' + ($SharedServicesVnetName))
  Write-Verbose -Message ('SOL0053-UseCaseVnetName: ' + ($UseCaseVnetName))

  #############################################################################################################################################################
  #
  # Create VNET peering - Use Case VNET -> Shared Services VNET
  #
  #############################################################################################################################################################
  $Result = PAT0053-NetworkVnetPeeringNew -Vnet1Name $SharedServicesVnetName -Vnet2Name $UseCaseVnetName

 
  ###########################################################################################################################################################
  #
  # Change to Use Case Subscription and get VNET information 
  #
  ###########################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionName} 
  $Result = Disconnect-AzureRmAccount
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0053-AzureContextChanged: ' + ($AzureContext | Out-String))

  $UseCaseVnetAddressRange = (Get-AzureRmVirtualNetwork -Name $UseCaseVnetName -ResourceGroupName $ResourceGroupNameUseCaseVnet).AddressSpace.AddressPrefixes
  
  Write-Verbose -Message ('SOL0053-UseCaseVnetName: ' + $UseCaseVnetName)
  Write-Verbose -Message ('SOL0053-UseCaseVnetAddressRange: ' + $UseCaseVnetAddressRange)

  #############################################################################################################################################################
  #
  # Update Palo Alto Firewalls
  #
  #############################################################################################################################################################
  # Get Firewalls
  $Firewalls = @()
  $Firewalls = (Get-AutomationVariable -Name VAR-AUTO-Firewalls) -split ','
  Write-Verbose -Message ('SOL0053-FirewallToConfigure: ' + ($Firewalls)) 

  # Configure each Firewall
  foreach ($Firewall in $Firewalls)
  {   
    Write-Verbose -Message ('SOL0053-ConfiguringFirewall: ' + $Firewall)

    # Configure Virtual Router vr_eth2 
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth2 -StaticRouteName default `
                                         -Destination 0.0.0.0/0 -NextHop vr_eth3

    # Configure Virtual Router vr_eth3 
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth3 -StaticRouteName default `
                                         -Destination 0.0.0.0/0 -NextHop 10.155.12.65                                                                            # VNET Gateway address
    
    # Configure Virtual Router vr_eth3 
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth3 -StaticRouteName $UseCaseVnetName `
                                         -Destination $UseCaseVnetAddressRange -NextHop vr_eth2
  }


  #############################################################################################################################################################
  #
  # Configure User Defined Routes - Route Internet bound traffic via the Firewall   
  #
  #############################################################################################################################################################
  InlineScript
  {
    $UseCaseVnetName = $Using:UseCaseVnetName
    $AzureAutomationCredential = $Using:AzureAutomationCredential
    $SubscriptionName = $Using:SubscriptionName
    $LoadBalancerIpAddress = $Using:LoadBalancerIpAddress

    # Route Table in Use Case Subscription
    $RouteTableUseCaseName = ($UseCaseVnetName -split('vnt'))[0] + 'rot-routetable-01'
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
    $RouteTableVnetUseCase = Get-AzureRmRouteTable | Where-Object {$_.Name -eq $RouteTableUseCaseName}
    Write-Verbose -Message ('SOL0050-RouteTableVnetUseCase: ' + ($RouteTableVnetUseCase | Out-String)) 
    $RouteTableVnetUseCase = $RouteTableVnetUseCase | Add-AzureRmRouteConfig -Name Internet `                                                                             -AddressPrefix '0.0.0.0/0' `
                                                                             -NextHopType VirtualAppliance `
                                                                             -NextHopIpAddress $LoadBalancerIpAddress `
                                                    | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                      # Suppress errors when overwriting existing routes
    Write-Verbose -Message ('SOL0050-RouteTableVnet1RoutesAdded: ' + ($RouteTableVnetUseCase | Out-String)) 
  }

}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnUJIE5UrXfIg0pAp9746TEDh
# 4sKgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUGYjVVfz08R59
# cF4l5A/sZAH+zxkwDQYJKoZIhvcNAQEBBQAEggEAy+RKIbkKWvm0S2mMurGar3lX
# UjNJSHdt3fgnzalnFWZJduuNBx3pEQRdimTq0d7j4/8J6t7qG/xzbRZsDmgg+jeI
# 4VS/r17Ssd0J5um2T7f7JIq6/tyaNw1isPGQB9sdSdmXpLlWQTwe+4dIOLjJHJPH
# +4h4BpwmN/ubo4Q387qSNoO5Tzg+OpH332hry5ckl4UWMG+d8jIw4fx92UuF8l29
# dB5uk7AVuOXgULr1+f21ALIdKbVeCHChY3op1DBEa2BT5PTskMyCwsmC81trJtNT
# zUIulkyDDL4Kcyqd5wAjp+OvfJZNX9IwaHrGsCZ6/Z/gHh39fKpSMMDIE1WU1w==
# SIG # End signature block
