###############################################################################################################################################################
# Establishes communication between two Use Case Subscriptions. The traffic flow is via Firewalls in the Shared Services Subscriptions. Therefore two
# peerings are established VNET1 -> Shared Services and VNET2 -> Shared Services.
# There is no direct traffic between the Use Case Subscriptions. User Defined Routes direct traffic via the Shared Services VNET.
# Additional Static Routes are configured in the Virtual Routers on the Firewalls.
# If the two VNETs to be peered are not in the same region, the first VNET name defines the VNET to be used in the Shared Services Subscription.
#
# Output:         None
#
# Requirements:   See Import-Module in code below / execution on Hybrid Runbook Worker
#
# Template:       SOL0050-NetworkUcToUcNew -ApplicationName $ApplicationName -ApplicationDNS $ApplicationDNS -PrivateIpAddress $PrivateIpAddress
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow SOL0050-NetworkUcToUcNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $Vnet1Name = 'weu-0010-vnt-01',                                                                                        # Defines the location of the Shared Services VNET
    [Parameter(Mandatory=$false)][String] $Vnet2Name = 'weu-0011-vnt-01'
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
  $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
  $LoadBalancerIpAddress = '10.155.12.38'

  # Shared Services Subscription
  $SharedServicesVnetName = ($Vnet1Name -split('-'))[0] + '-0005-vnt-01'
  $SharedServicesVnet = Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $SharedServicesVnetName}
  $SharedServicesAddressSpace = (Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $SharedServicesVnetName}).AddressSpace.AddressPrefixes
  $RouteTableVnetSharedServicesName = ($SharedServicesVnetName -split('vnt'))[0] + 'rot-routetable-01'
  $SharedServicesSubscriptionName = (Get-AzureRmContext).Subscription.Name

  # Get Firewall details - required to configure the custom routes
  $FirewallDetails = InlineScript
  { 
    $Firewalls = @()
    $Firewalls = (Get-AutomationVariable -Name VAR-AUTO-Firewalls) -split ','
    Write-Verbose -Message ('SOL0059-FirewallsToConfigure: ' + ($Firewalls)) 
    $FirewallDetails = @()
    foreach ($Firewall in $Firewalls)
    {
      $Nic = Get-AzureRmNetworkInterface | Where-Object {$_.IpConfigurations.PrivateIpAddress -eq $Firewall}
      $FirewallDetails += [pscustomobject] @{Name = $Nic.Name.Split('-')[0];PrivateIpAddress = $Nic.IpConfigurations.PrivateIpAddress}
    }
    Return $FirewallDetails
  }
  Write-Verbose -Message ('SOL0059-FirewallDetails: ' + ($FirewallDetails | Out-String))

  # VNET1 Subscription
  $Vnet1SubscriptionCode = $Vnet1Name.Split('-')[1]
  $Vnet1SubscriptionName = (Get-AzureRmSubscription | Where-Object {$_.Name -match $Vnet1SubscriptionCode}).Name
  $Result = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet1SubscriptionName -Force
  $Vnet1AddressSpace = (Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $Vnet1Name}).AddressSpace.AddressPrefixes
  $RouteTableVnet1Name = ($Vnet1Name -split('vnt'))[0] + 'rot-routetable-01'

  # VNET2 Subscription
  $Vnet2SubscriptionCode = $Vnet2Name.Split('-')[1]
  $Vnet2SubscriptionName = (Get-AzureRmSubscription | Where-Object {$_.Name -match $Vnet2SubscriptionCode}).Name
  $Result = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet2SubscriptionName -Force
  $Vnet2AddressSpace = (Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $Vnet2Name}).AddressSpace.AddressPrefixes
  $RouteTableVnet2Name = ($Vnet2Name -split('vnt'))[0] + 'rot-routetable-01'

  Write-Verbose -Message ('SOL0050-SharedServicesVnetName: ' + ($SharedServicesVnetName))
  Write-Verbose -Message ('SOL0050-Vnet1Name: ' + ($Vnet1Name))
  Write-Verbose -Message ('SOL0050-Vnet2Name: ' + ($Vnet2Name))
  Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServicesName: ' + ($RouteTableVnetSharedServicesName))
  Write-Verbose -Message ('SOL0050-RouteTableVnet1Name: ' + ($RouteTableVnet1Name))
  Write-Verbose -Message ('SOL0050-RouteTableVnet2Name: ' + ($RouteTableVnet2Name))
  Write-Verbose -Message ('SOL0050-SharedServicesSubscriptionName: ' + ($SharedServicesSubscriptionName))
  Write-Verbose -Message ('SOL0050-Vnet1SubscriptionName: ' + ($Vnet1SubscriptionName))
  Write-Verbose -Message ('SOL0050-Vnet2SubscriptionName: ' + ($Vnet2SubscriptionName))
  Write-Verbose -Message ('SOL0050-Vnet1AddressSpace: ' + ($Vnet1AddressSpace)) 
  Write-Verbose -Message ('SOL0050-Vnet2AddressSpace: ' + ($Vnet2AddressSpace)) 


  #############################################################################################################################################################
  #
  # Create VNET peering - VNET1 -> Shared Services / VNET2 -> Shared Services
  #
  #############################################################################################################################################################
  $Result = PAT0053-NetworkVnetPeeringNew -Vnet1Name $SharedServicesVnetName -Vnet2Name $Vnet1Name
  $Result = PAT0053-NetworkVnetPeeringNew -Vnet1Name $SharedServicesVnetName -Vnet2Name $Vnet2Name   


  #############################################################################################################################################################
  #
  # Configure User Defined Routes - Route traffic between all three VNETs via the Firewall   
  #
  #############################################################################################################################################################
  InlineScript
  {
    $AzureAutomationCredential = $Using:AzureAutomationCredential
    $Vnet1SubscriptionName = $Using:Vnet1SubscriptionName
    $Vnet2SubscriptionName = $Using:Vnet2SubscriptionName
    $SharedServicesSubscriptionName = $Using:SharedServicesSubscriptionName
    $RouteTableVnet1Name = $Using:RouteTableVnet1Name
    $RouteTableVnet2Name = $Using:RouteTableVnet2Name
    $RouteTableVnetSharedServicesName = $Using:RouteTableVnetSharedServicesName
    $Vnet1Name = $Using:Vnet1Name
    $Vnet2Name = $Using:Vnet2Name
    $Vnet1AddressSpace = $Using:Vnet1AddressSpace
    $Vnet2AddressSpace = $Using:Vnet2AddressSpace
    $SharedServicesVnetName = $Using:SharedServicesVnetName
    $SharedServicesAddressSpace = $Using:SharedServicesAddressSpace
    $FirewallDetails = $Using:FirewallDetails
    $LoadBalancerIpAddress = $Using:LoadBalancerIpAddress

    # Route Table for VNET1 - on-premise
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet1SubscriptionName -Force
    $RouteTableVnet1 = Get-AzureRmRouteTable | Where-Object {$_.Name -eq $RouteTableVnet1Name}
    Write-Verbose -Message ('SOL0050-RouteTableVnet1: ' + ($RouteTableVnet1 | Out-String)) 
    $RouteTableVnet1 = $RouteTableVnet1 | Add-AzureRmRouteConfig -Name $Vnet2Name `                                                                 -AddressPrefix ([string]$Vnet2AddressSpace) `
                                                                 -NextHopType VirtualAppliance `
                                                                 -NextHopIpAddress $LoadBalancerIpAddress `
                                        | Add-AzureRmRouteConfig -Name $SharedServicesVnetName `
                                                                 -AddressPrefix ([string]$SharedServicesAddressSpace) `
                                                                 -NextHopType VirtualAppliance `
                                                                 -NextHopIpAddress $LoadBalancerIpAddress `
                                        | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                                    # Suppress errors when overwriting existing routes
    Write-Verbose -Message ('SOL0050-RouteTableVnet1RoutesAdded: ' + ($RouteTableVnet1 | Out-String)) 

    foreach ($FirewallDetail in $FirewallDetails)                                                                                                                # Configure the route for the return traffic, bypassing the load balancer
    {
      $RouteTableVnet1 = $RouteTableVnet1 | Add-AzureRmRouteConfig -Name $FirewallDetail.Name `                                                                   -AddressPrefix ($FirewallDetail.PrivateIpAddress + '/32') `
                                                                   -NextHopType VirtualAppliance `
                                                                   -NextHopIpAddress $FirewallDetail.PrivateIpAddress `
                                          | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                                  # Suppress errors when overwriting existing routes
    }
    Write-Verbose -Message ('SOL0050-RouteTableVnet1RoutesAdded: ' + ($RouteTableVnet1 | Out-String)) 

    # Route Table for VNET2 - trusted (Azure VNETs)
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Vnet2SubscriptionName -Force
    $RouteTableVnet2 = Get-AzureRmRouteTable | Where-Object {$_.Name -match $RouteTableVnet2Name}
    Write-Verbose -Message ('SOL0050-RouteTableVnet2: ' + ($RouteTableVnet2 | Out-String)) 
    $RouteTableVnet2 = $RouteTableVnet2 | Add-AzureRmRouteConfig -Name $Vnet1Name `                                                                 -AddressPrefix ([string]$Vnet1AddressSpace) `
                                                                 -NextHopType VirtualAppliance `
                                                                 -NextHopIpAddress $LoadBalancerIpAddress `
                                        | Add-AzureRmRouteConfig -Name $SharedServicesVnetName `
                                                                 -AddressPrefix ([string]$SharedServicesAddressSpace) `
                                                                 -NextHopType VirtualAppliance `
                                                                 -NextHopIpAddress $LoadBalancerIpAddress `
                                        | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                                    # Suppress errors when overwriting existing routes
    Write-Verbose -Message ('SOL0050-RouteTableVnet2RoutesAdded: ' + ($RouteTableVnet2 | Out-String)) 

    foreach ($FirewallDetail in $FirewallDetails)                                                                                                                # Configure the route for the return traffic, bypassing the load balancer
    {
      $RouteTableVnet2 = $RouteTableVnet2 | Add-AzureRmRouteConfig -Name $FirewallDetail.Name `                                                                   -AddressPrefix ($FirewallDetail.PrivateIpAddress + '/32') `
                                                                   -NextHopType VirtualAppliance `
                                                                   -NextHopIpAddress $FirewallDetail.PrivateIpAddress `
                                          | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                                  # Suppress errors when overwriting existing routes
    }
    Write-Verbose -Message ('SOL0050-RouteTableVnet2RoutesAdded: ' + ($RouteTableVnet2 | Out-String))

    # Route Table for Shared Services VNET - untrusted (Internet)
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SharedServicesSubscriptionName -Force
    $RouteTableVnetSharedServices = Get-AzureRmRouteTable | Where-Object {$_.Name -match $RouteTableVnetSharedServicesName}
    Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServices: ' + ($RouteTableVnetSharedServices | Out-String)) 
    $RouteTableVnetSharedServices = $RouteTableVnetSharedServices | Add-AzureRmRouteConfig -Name $Vnet2Name `                                                                                           -AddressPrefix ([string]$Vnet2AddressSpace) `
                                                                                           -NextHopType VirtualAppliance `
                                                                                           -NextHopIpAddress $LoadBalancerIpAddress `
                                                                  | Add-AzureRmRouteConfig -Name $Vnet1Name `                                                                                           -AddressPrefix ([string]$Vnet1AddressSpace) `
                                                                                           -NextHopType VirtualAppliance `
                                                                                           -NextHopIpAddress $LoadBalancerIpAddress `
                                                                  | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                          # Suppress errors when overwriting existing routes
    Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServicesRoutesAdded: ' + ($RouteTableVnetSharedServices | Out-String)) 

    foreach ($FirewallDetail in $FirewallDetails)                                                                                                                # Configure the route for the return traffic, bypassing the load balancer
    {
      $RouteTableVnetSharedServices = $RouteTableVnetSharedServices | Add-AzureRmRouteConfig -Name $FirewallDetail.Name `                                                                                              -AddressPrefix ($FirewallDetail.PrivateIpAddress + '/32') `
                                                                                              -NextHopType VirtualAppliance `
                                                                                              -NextHopIpAddress $FirewallDetail.PrivateIpAddress `
                                                                     | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                       # Suppress errors when overwriting existing routes
    }
    Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServicesRoutesAdded: ' + ($RouteTableVnetSharedServices | Out-String)) 
  }

  #############################################################################################################################################################
  #
  # Configure the Firewalls - Configure additional Static Routes on Virtual Routers
  #
  #############################################################################################################################################################
  # Get Firewalls
  $Firewalls = @()
  $Firewalls = (Get-AutomationVariable -Name VAR-AUTO-Firewalls) -split ','
  Write-Verbose -Message ('SOL0050-FirewallToConfigure: ' + ($Firewalls)) 

  # Configure each Firewall
  foreach ($Firewall in $Firewalls)
  {   
    # Configure Virtual Router vr_eth2 for VNET1 -> next hop is IP address
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth2 -StaticRouteName $Vnet1Name `                               -Destination $Vnet1AddressSpace -NextHop 10.155.12.33
  
    # Configure Virtual Router vr_eth2 for VNET2 -> next hop is IP address
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth2 -StaticRouteName $Vnet2Name `                               -Destination $Vnet2AddressSpace -NextHop 10.155.12.33                                 
  }


  #############################################################################################################################################################
  #
  # Update CMDB
  #
  #############################################################################################################################################################
  # This has to be added based on the chosen CMDB implementation


  #############################################################################################################################################################
  #
  # Update Service Request
  #
  #############################################################################################################################################################
  # This has to be added based on the chosen Server Request portal implementation
  
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0EneX/LEyy9mF3eKTYVPx7qN
# erugggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYS1YwoU4WM26
# 9oaPGmgP/9xyZaIwDQYJKoZIhvcNAQEBBQAEggEAGI6DCRR/u5j+aCAoxdKgFDo3
# EjYfT3bHOIKYn08XTJ7VRXyRm560dj0Te//1ZJzLQHw7ywx8R6jnca8l1FhP2FrA
# 0gLi5kgR5/WPEt4Xcg8l9pZuu2HI16huzH6IoXGucuu6Uo1pjUMviW0dEytyQT1t
# PG/QIVfSExfjQb4pRNlAVhJm44ibCvFGE8O1LKGuOG9eZz7S0JJpY9SGo7V2HsOR
# qZOcwmvQIKnnVlDfjQSJxgxczPm20nyIJTQ8abB8JqLvG0vkke4AnvCNZe+v9kvm
# g9FNSPj3kQNa9GIOY9uGsiolNewGJRB5qyqBp+L/P7qwYW7azjs9WD5oXf/cRw==
# SIG # End signature block
