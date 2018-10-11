###############################################################################################################################################################
# On-boarding a business application running on a server in Azure for access from the Internet. The Runbook will configure the Public Load Balancer as well
# as the Palo Alto Firewalls.
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#                
#
# Template:       SOL0059-FirewallApplicationAdd -ApplicationName $ApplicationName -ApplicationDNS $ApplicationDNS -PrivateIpAddress $PrivateIpAddress
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow SOL0059-NetworkInternetToUcNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionName = 'RT_S0010_ RECF_SND0010',                                                                          # Where the application is running
    [Parameter(Mandatory=$false)][String] $Region = 'West Europe',                                                                                               # Where the application is running
    [Parameter(Mandatory=$false)][String] $ApplicationName = 'FelixTestApp1',
    [Parameter(Mandatory=$false)][String] $ApplicationDNS = 'FelixTestAppDns1',
    [Parameter(Mandatory=$false)][String] $PrivateIpAddress = '10.155.13.4',                                                                                     # Where the application is running
    [Parameter(Mandatory=$false)][String] $PrivateIpAddressPort = '88'                                                                                           # Where the application is running
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

  # Create Region Code
  $RegionCode = InlineScript 
  {
    $Region = $Using:Region
    $RegionCode = switch ($Region) 
    {   
      'West Europe' {'weu'} 
      'North Europe' {'neu'}
      'West US' {'wus'}
      'East US' {'eus'}
      'Southeast Asia' {'sea'}
      'East Asia' {'eas'}
    }
    Return $RegionCode
  }
  
  $SubscriptionCode = ($SubscriptionName.Split('_')[1]).Substring(1,4)
  $SharedServicesVnetName = $RegionCode + '-' + '0005' + '-vnt-01'
  $UseCaseVnetName = $RegionCode + '-' + $SubscriptionCode + '-vnt-01'  
  $ResourceGroupNameUseCaseVnet = $RegionCode + '-' + $SubscriptionCode + '-rsg-network-01'                                                                      # e.g. weu-0010-rsg-network-01

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
  Write-Verbose -Message ('SOL0059-SubscriptionName: ' + ($SubscriptionName))
  Write-Verbose -Message ('SOL0059-Region: ' + ($Region))
  Write-Verbose -Message ('SOL0059-ApplicationName: ' + ($ApplicationName))
  Write-Verbose -Message ('SOL0059-ApplicationDNS: ' + ($ApplicationDNS))
  Write-Verbose -Message ('SOL0059-PrivateIpAddress: ' + ($PrivateIpAddress))
  Write-Verbose -Message ('SOL0059-RegionCode: ' + ($RegionCode))
  Write-Verbose -Message ('SOL0059-SubscriptionCode: ' + ($SubscriptionCode))
  Write-Verbose -Message ('SOL0059-SharedServicesVnetName: ' + ($SharedServicesVnetName))
  Write-Verbose -Message ('SOL0059-UseCaseVnetName: ' + ($UseCaseVnetName))

  #############################################################################################################################################################
  #
  # Create VNET peering - Use Case VNET -> Shared Services VNET
  #
  #############################################################################################################################################################
  $Result = PAT0053-NetworkVnetPeeringNew -Vnet1Name $SharedServicesVnetName -Vnet2Name $UseCaseVnetName

  TEC0005-AzureContextSet

  $PublicIpAddressFqdn = InlineScript
  {
    $ApplicationName = $Using:ApplicationName
    $ApplicationDNS = $Using:ApplicationDNS
    $PrivateIpAddress = $Using:PrivateIpAddress


    ###########################################################################################################################################################
    #
    # Determine Load Balancer with fewest Frontend IPs - up to 200/600 for Basic/Standard Load Balancers 
    #
    ###########################################################################################################################################################
    # Get all Load Balancers in Subscriptions
    $LoadBalancers = Get-AzureRmLoadBalancer
    Write-Verbose -Message ('SOL0059-LoadBalancers: ' + ($LoadBalancers.Name))

    # Get all external Load Balancers
    $LoadBalancersExternal = $LoadBalancers | Where-Object {$_.FrontendIpConfigurations.PublicIpAddress.Id -ne $null}
    Write-Verbose -Message ('SOL0059-LoadBalancersExternal: ' + ($LoadBalancersExternal.Name))

    # Get the Load Balancer with the fewest Frontend IPs
    $Table = @{}
    foreach ($LoadBalancer in $LoadBalancersExternal)
    {
      $Table.Add($LoadBalancer.Name, $LoadBalancer.FrontendIpConfigurations.Count)
    }
    $LoadBalancerName = ($Table.GetEnumerator() | Sort-Object Value).Name | Select-Object -First 1
    $LoadBalancer = $LoadBalancers | Where-Object {$_.Name -eq $LoadBalancerName}
    Write-Verbose -Message ('SOL0059-LoadBalancerToBeConfigured: ' + ($LoadBalancer | Out-String)) 


    #############################################################################################################################################################
    #
    # Create Public IP and update Load Balancer
    #
    #############################################################################################################################################################
    # Define names
    $FrontendIpName = $LoadBalancer.FrontendIpConfigurations.Name | Sort-Object -Descending | Select-Object -First 1
    $FrontendIpName = ($FrontendIpName.Substring(0,$FrontendIpName.Length-2)) + ([int]$FrontendIpName.Substring($FrontendIpName.Length-2, 2) + 1).ToString('00')
    $1, $2, $3, $4, $5, $6 = $FrontendIpName.Split('-')
    $PublicIpAddressName = $1 + '-' + $2 + '-' + 'llb' + '-' + $4 + '-' + $5 + '-' + $6
    Write-Verbose -Message ('SOL0059-FrontendIpName: ' + ($FrontendIpName)) 
    Write-Verbose -Message ('SOL0059-PublicIpAddressName: ' + ($PublicIpAddressName)) 

    # Create new Public IP Address
    $PublicIpAddress = New-AzureRmPublicIpAddress -Name $PublicIpAddressName -ResourceGroupName $LoadBalancer.ResourceGroupName -AllocationMethod Static `
                                                  -DomainNameLabel $ApplicationDns.ToLower() -Location $LoadBalancer.Location -Tag $LoadBalancer.Tag
    Write-Verbose -Message ('SOL0059-PublicIpAddressCreated: ' + ($PublicIpAddress | Out-String))

    # Create new Frontend IP based on Public IP Address created above
    $LoadBalancer = Add-AzureRmLoadBalancerFrontendIpConfig -LoadBalancer $LoadBalancer -Name $FrontendIpName -PublicIpAddressId $PublicIpAddress.Id

    # Create rule - using new Frontend IP with existing Backend Address Pool and Probe
    $LoadBalancingRule = $LoadBalancer.LoadBalancingRules | Sort-Object -Property Name -Descending | Select-Object -First 1
    if ($LoadBalancingRule.Length -ne 0)
    { 
      $LoadBalancingRuleName = ($LoadBalancingRule.Name.Substring(0,$LoadBalancingRule.Name.Length-2)) + `
                               ([int]$LoadBalancingRule.Name.Substring($LoadBalancingRule.Name.Length-2, 2) + 1).ToString('00')
    }
    else
    {
      $LoadBalancingRuleName = $LoadBalancer.Name + '-lbr01'
    }
    Write-Verbose -Message ('SOL0059-LoadBalancingRuleName: ' + ($LoadBalancingRuleName))
        $LoadBalancer = Add-AzureRmLoadBalancerRuleConfig -LoadBalancer $LoadBalancer `                                                      -Name $LoadBalancingRuleName `                                                      -FrontendIpConfigurationId ($LoadBalancer.FrontendIpConfigurations `                                                                                 | Sort-Object -Property Name -Descending `
                                                                                 | Select-Object -First 1 -ExpandProperty Id) `
                                                      -BackendAddressPoolId $LoadBalancer.BackendAddressPools[0].Id `                                                      -ProbeId $LoadBalancer.Probes[0].Id `                                                      -Protocol Tcp `                                                      -FrontendPort 80 `                                                      -BackendPort 80 `
                                                      -LoadDistribution SourceIPProtocol `
                                                      -EnableFloatingIP

    # Update load balancer
    $LoadBalancer = Set-AzureRmLoadBalancer -LoadBalancer $LoadBalancer    Write-Verbose -Message ('SOL0059-LoadBalancerConfigured: ' + ($LoadBalancer | Out-String)) 

    Return $PublicIpAddress.DnsSettings.Fqdn
  }

  ###########################################################################################################################################################
  #
  # Change to Use Case Subscription and get VNET information 
  #
  ###########################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionName} 
  $Result = Disconnect-AzureRmAccount
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0059-AzureContextChanged: ' + ($AzureContext | Out-String))

  $UseCaseVnetAddressRange = (Get-AzureRmVirtualNetwork -Name $UseCaseVnetName -ResourceGroupName $ResourceGroupNameUseCaseVnet).AddressSpace.AddressPrefixes
  
  Write-Verbose -Message ('SOL0059-Fqdn: ' + $PublicIpAddressFqdn)
  Write-Verbose -Message ('SOL0059-PrivateIpAddress: ' + $PrivateIpAddress)
  Write-Verbose -Message ('SOL0059-UseCaseVnetName: ' + $UseCaseVnetName)
  Write-Verbose -Message ('SOL0059-UseCaseVnetAddressRange: ' + $UseCaseVnetAddressRange)

  #############################################################################################################################################################
  #
  # Update Palo Alto Firewalls
  #
  #############################################################################################################################################################
  # Get Firewalls
  $Firewalls = @()
  $Firewalls = (Get-AutomationVariable -Name VAR-AUTO-Firewalls) -split ','
  Write-Verbose -Message ('SOL0059-FirewallToConfigure: ' + ($Firewalls)) 

  # Configure each Firewall
  foreach ($Firewall in $Firewalls)
  {   
    Write-Verbose -Message ('SOL0059-ConfiguringFirewall: ' + $Firewall)

    # Configure an Address Object with the FQDn
    $Result = PAT0059-NetworkPaloAltoSet -Function Object-Address -Firewall $Firewall -Fqdn $PublicIpAddressFqdn
    
    # Configure a NAT Policy
    $Result = PAT0059-NetworkPaloAltoSet -Function Policy-NAT -Firewall $Firewall -Fqdn $PublicIpAddressFqdn -PrivateIpAddress $PrivateIpAddress `                                         -PrivateIpAddressPort $PrivateIpAddressPort -ApplicationName $ApplicationName

    # Configure Virtual Router vr_eth3 
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth3 -StaticRouteName $UseCaseVnetName `
                                         -Destination $UseCaseVnetAddressRange -NextHop vr_eth2
    
    # Configure Virtual Router vr_eth2 
    $Result = PAT0059-NetworkPaloAltoSet -Function VirtualRouter-StaticRoute -Firewall $Firewall -VirtualRouter vr_eth2 -StaticRouteName $UseCaseVnetName `
                                         -Destination $UseCaseVnetAddressRange -NextHop 10.155.12.33
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
    $FirewallDetails = $Using:FirewallDetails
    $SharedServicesSubscriptionName = $Using:SharedServicesSubscriptionName
    $LoadBalancerIpAddress = $Using:LoadBalancerIpAddress
    $UseCaseVnetAddressRange = $Using:UseCaseVnetAddressRange

    # Route Table in Use Case Subscription
    $RouteTableUseCaseName = ($UseCaseVnetName -split('vnt'))[0] + 'rot-routetable-01'
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
    $RouteTableVnetUseCase = Get-AzureRmRouteTable | Where-Object {$_.Name -eq $RouteTableUseCaseName}
    Write-Verbose -Message ('SOL0050-RouteTableVnet1: ' + ($RouteTableVnetUseCase | Out-String)) 
    foreach ($FirewallDetail in $FirewallDetails)                                                                                                                # Configure the route for the return traffic, bypassing the load balancer
    {
      $RouteTableVnetUseCase = $RouteTableVnetUseCase | Add-AzureRmRouteConfig -Name $FirewallDetail.Name `                                                                               -AddressPrefix ($FirewallDetail.PrivateIpAddress + '/32') `
                                                                               -NextHopType VirtualAppliance `
                                                                               -NextHopIpAddress $FirewallDetail.PrivateIpAddress `
                                                       | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                                      # Suppress errors when overwriting existing routes
    }
    Write-Verbose -Message ('SOL0050-RouteTableVnet1RoutesAdded: ' + ($RouteTableVnetUseCase | Out-String)) 

    # Route Table in Shared Services Subscription
    $SharedServicesVnetName = ($UseCaseVnetName -split('-'))[0] + '-0005-vnt-01'
    $RouteTableVnetSharedServicesName = ($SharedServicesVnetName -split('vnt'))[0] + 'rot-routetable-01'
    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SharedServicesSubscriptionName -Force
    $RouteTableVnetSharedServices = Get-AzureRmRouteTable | Where-Object {$_.Name -match $RouteTableVnetSharedServicesName}
    Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServices: ' + ($RouteTableVnetSharedServices | Out-String)) 
    $RouteTableVnetSharedServices = $RouteTableVnetSharedServices | Add-AzureRmRouteConfig -Name $UseCaseVnetName `                                                                                           -AddressPrefix ([string]$UseCaseVnetAddressRange) `
                                                                                           -NextHopType VirtualAppliance `
                                                                                           -NextHopIpAddress $LoadBalancerIpAddress `
                                                                   | Set-AzureRmRouteTable -ErrorAction SilentlyContinue                                          # Suppress errors when overwriting existing routes
    Write-Verbose -Message ('SOL0050-RouteTableVnetSharedServicesRoutesAdded: ' + ($RouteTableVnetSharedServices | Out-String)) 
  }

}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUF95HKxKCnjpa8dEdZ2vKrLXS
# viigggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUgMOaZH8WeMfq
# MH4tGuJf+A/jNfIwDQYJKoZIhvcNAQEBBQAEggEAxyjnoQqK8ovlYbQ8HyilXGRT
# dtdmZVcmwPbRf+yO1wmEqExzf0biIlohRVJ9XFCpO/rupghRwvNqx4SHqip5yzfM
# EFvkn/8TMV0btV8ka09ZQRiWobVTxxUWzkPfNHfSViGocTwvX6w7LEjxtNBLy+QC
# m4SeXzH3k6ah/nZd1x7DhvaxTf5l86ZlaKl/JT/V0yMH/CdY8EEatS2CLdU9kRak
# RCCQXFFHw3+PR+dX1TROQER4DAXUGvo6HmJ0NP882aUiFBGrO2ti9hvxgsp13KsV
# DRWrpe6TZAZSa/aJ/Mbs510ZXfrewLFzzTpg08ECYVVUnxMPVsihZBlj3lKzvA==
# SIG # End signature block
