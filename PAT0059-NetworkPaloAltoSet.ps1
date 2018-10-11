###############################################################################################################################################################
# Configures a Palo Alto firewall, based on the $Function and parameters. The error handling is limited to ensuring there is a return code of '200' on the 
# REST call. All other errors such as wrong parameters that prevent the successful execution of the change are not covered. 
#
# Output:         'Success' or 'Failure'
#
# Requirements:   See Import-Module in code below / Firewall
#
# Template:       PAT0059-NetworkPaloAltoSet -Function $Function -Firewall $Firewall -VirtualRouter $VirtualRouter `#                                            -StaticRouteName $StaticRouteName -Destination $Destination -NextHop $NextHop -Fqdn $Fqdn `#                                            -PrivateIpAddress $PrivateIpAddress -PrivateIpAddressPort $PrivateIpAddressPort -ApplicationName $ApplicationName
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0059-NetworkPaloAltoSet
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $Function = 'VirtualRouter-StaticRoute',
    [Parameter(Mandatory=$false)][String] $Firewall = '10.155.12.101',
    [Parameter(Mandatory=$false)][String] $VirtualRouter = 'vr_eth2',
    [Parameter(Mandatory=$false)][String] $StaticRouteName = 'weu-0011-vnt-01',
    [Parameter(Mandatory=$false)][String] $Destination = '10.155.18.0/26',
    [Parameter(Mandatory=$false)][String] $NextHop = '10.155.12.33',                                                                                             #'vr_eth2' / 10.155.12.33
    [Parameter(Mandatory=$false)][String] $Fqdn = 'felixtestappdns1.westeurope.cloudapp.azure.com',
    [Parameter(Mandatory=$false)][String] $PrivateIpAddress = '10.155.13.36',
    [Parameter(Mandatory=$false)][String] $PrivateIpAddressPort = '80',
    [Parameter(Mandatory=$false)][String] $ApplicationName = 'felixtestappdns1'
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    # $Result = Import-Module 
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $Result = InlineScript
  { 
    $Function = $Using:Function
    $Firewall = $Using:Firewall
    $VirtualRouter = $Using:VirtualRouter
    $StaticRouteName = $Using:StaticRouteName
    $Destination = $Using:Destination
    $NextHop = $Using:NextHop
    $Fqdn = $Using:Fqdn
    $PrivateIpAddress = $Using:PrivateIpAddress
    $PrivateIpAddressPort = $Using:PrivateIpAddressPort
    $ApplicationName = $Using:ApplicationName


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    # Header with credentials
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
    $Username = $AzureAutomationCredential.GetNetworkCredential().username.Split('@').ToLower()
    $Password = $AzureAutomationCredential.GetNetworkCredential().password
    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Username[0] + ':' + $Password))
    $Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo)}  
    Write-Verbose -Message ('PAT0059-Headers: ' + ($Headers | Out-String)) 

    # URI for Firewall
    $FirewallUri = "http://$Firewall/api/?type"
    Write-Verbose -Message ('PAT0059-FirewallUri: ' + ($FirewallUri)) 

    Write-Verbose -Message ('PAT0059-Function: ' + ($Function))
    Write-Verbose -Message ('PAT0059-Firewall: ' + ($Firewall))
    Write-Verbose -Message ('PAT0059-VirtualRouter: ' + ($VirtualRouter))
    Write-Verbose -Message ('PAT0059-StaticRouteName: ' + ($StaticRouteName))
    Write-Verbose -Message ('PAT0059-Destination: ' + ($Destination))
    Write-Verbose -Message ('PAT0059-NextHop: ' + ($NextHop))
    Write-Verbose -Message ('PAT0059-Fqdn: ' + ($Fqdn))
    Write-Verbose -Message ('PAT0059-PrivateIpAddress: ' + ($PrivateIpAddress))
    Write-Verbose -Message ('PAT0059-PrivateIpAddressPort: ' + ($PrivateIpAddressPort))
    Write-Verbose -Message ('PAT0059-ApplicationName: ' + ($ApplicationName))

    if ($Function -eq 'VirtualRouter-StaticRoute')
    { 
      ###########################################################################################################################################################
      #  
      # Configure Static Route on Virtual Router -> Network -> Virtual Routers
      #
      ###########################################################################################################################################################
      # Determine nexthop type
      if ($NextHop -like '*.*')
      {
        $NextHop = "<ip-address>$NextHop</ip-address>"
      }
      else
      {
        $NextHop = "<next-vr>$NextHop</next-vr>"
      }

      # Configure Interface name
      $Interface = 'ethernet1/' + $VirtualRouter.Substring(6,1)

      #Configure Static Route
      $Xpath = "/config/devices/entry[@name='localhost.localdomain']/network/virtual-router/entry[@name='$VirtualRouter']/routing-table/ip/static-route/entry[@name=" + "'" + $StaticRouteName + "'" + "]"
      $Element = "<nexthop>
                    $NextHop
                  </nexthop>
                  <bfd>
                    <profile>None</profile>
                  </bfd>
                  <path-monitor>
                    <enable>no</enable>
                    <failure-condition>any</failure-condition>
                    <hold-time>2</hold-time>
                  </path-monitor>
                  <interface>$Interface</interface>
                  <metric>10</metric>
                  <destination>$Destination</destination>
                  <route-table>
                    <unicast/>
                  </route-table>"
      $Uri = "$FirewallUri=config&action=set&xpath=$Xpath&element=$Element"
      $Result = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing -Verbose:$false
      if ($Result.StatusCode -ne '200')
      {
        Write-Error -Message ('PAT0059-StaticRouteConfigurationFailed: ' + ($Result | Out-string))
        Return 'Failure'
      }
      Write-Verbose -Message ('PAT0059-StaticRouteConfigured: ' + ($Result | Out-string)) 
    }
    elseif ($Function -eq 'Object-Address')
    {
      ###########################################################################################################################################################
      #  
      # Configure Address - Objects -> Addresses
      #
      ###########################################################################################################################################################
      $Xpath = "/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/address/entry[@name=" + "'" + $Fqdn + "'" + "]"
      $Element = "<fqdn>$Fqdn</fqdn>"
      $Uri = "$FirewallUri=config&action=set&xpath=$Xpath&element=$Element"
      $Result = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing -Verbose:$false
      if ($Result.StatusCode -ne '200')
      {
        Write-Error -Message ('PAT0059-AddressObjectAdditionFailed: ' + ($Result | Out-string))
        Return 'Failure'
      }
      Write-Verbose -Message ('PAT0059-AddressObjectAdded: ' + ($Result | Out-string))
    }

    elseif ($Function -eq 'Policy-NAT')
    {
      ###########################################################################################################################################################
      #  
      # Configure IP Address and NAT Policy - Policies -> NAT -> Add
      #
      ###########################################################################################################################################################
      $Xpath = "/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/rulebase/nat/rules/entry[@name=" + "'" + $ApplicationName + "'" + "]"
      $Element = "<source-translation>
                    <dynamic-ip-and-port>
                      <interface-address>
                        <interface>ethernet1/2</interface>
                      </interface-address>
                    </dynamic-ip-and-port>
                  </source-translation>
                  <to>
                    <member>untrusted</member>
                  </to>
                  <from>
                    <member>untrusted</member>
                  </from>
                  <source>
                    <member>any</member>
                  </source>
                  <destination>
                    <member>$Fqdn</member>
                  </destination>
                  <service>any</service>
                  <destination-translation>
                    <translated-address>$PrivateIpAddress</translated-address>
                    <translated-port>$PrivateIpAddressPort</translated-port>
                  </destination-translation>"
      $Uri = "$FirewallUri=config&action=set&xpath=$Xpath&element=$Element"
      $Result = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing -Verbose:$false
      if ($Result.StatusCode -ne '200')
      {
        Write-Error -Message ('PAT0059-NatPolicyAdditionFailed: ' + ($Result | Out-string))
        Return 'Failure'
      }
      Write-Verbose -Message ('PAT0059-NatPolicyAdded: ' + ($Result | Out-string))
    }


    ###########################################################################################################################################################
    #  
    # Commit Changes
    #
    ###########################################################################################################################################################
    $Uri = "$FirewallUri=commit&cmd=<commit><force></force></commit>"
    $Result = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing -Verbose:$false
    
    if ($Result.StatusCode -ne '200')
    {
      Write-Error -Message ('PAT0059-CommitFailed: ' + ($Result | Out-string))
      Return 'Failure'
    }
    Write-Verbose -Message ('PAT0059-CommitExecutedOnFirewall: '+ ($Result | Out-string))
    Return 'Success'
  }
  Return $Result
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+M5+QJAPrksOefMYmzRG3Dse
# 67ygggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+vmOWd2cQdOD
# td10juSaylVQREYwDQYJKoZIhvcNAQEBBQAEggEAjKIN4G/Wb6idD4exzy/crpxc
# 63HLeREcVr+Xivle90+dLV7G3QNiCdUHfOPiCBwFDyZfYW+z/eytz/rACRVxSKAF
# +F+35nmVLFDsseFG5EFHg6U3+oCdPYBaxJJ026QZauscBWabQLo2NuZPRVai7+zt
# /A+YS8hSKrVLnhXPXFfFFtU29c/1LZiUTg2aQpMQkkbPPLLTugkxhI8B7p1jpAUq
# G19yGxg1t+cpUv2SmrCb35Z9u77TOXtvHQhMkueoakd1/hvvYLDqeM1uQLckQaI8
# u8prUHW4bLYmLF2UixCSr7DHZuv9sUb+7JngvdkzRuTw+64LroRyA0z6Rj4n2g==
# SIG # End signature block
