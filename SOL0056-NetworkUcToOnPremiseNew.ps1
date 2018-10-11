###############################################################################################################################################################
# Enable communication from a Use Case Subscriptions to on-Premise via the Gateway in the Shared Services Subscription.
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#                
#
# Template:       SOL0056-NetworkUcToOnPremiseNew -SubscriptionName $SubscriptionName -VnetName $VnetName
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow SOL0056-NetworkUcToOnPremiseNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionName = 'RT_S0010_ RECF_SND0010',                                                                          # Use Case Subscription
    [Parameter(Mandatory=$false)][String] $UseCaseVnetName = 'weu-0010-vnt-01'                                                                                   # VNET for which access is required
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
  $RegionCode = $UseCaseVnetName.Split('-')[0]
  $SubscriptionCode = ($SubscriptionName.Split('_')[1]).Substring(1,4)
  $SharedServicesVnetName = $RegionCode + '-' + '0005' + '-vnt-01'
  $RouteTableName = ($UseCaseVnetName -split('vnt'))[0] + 'rot-routetable-01'

  Write-Verbose -Message ('SOL0056-SubscriptionName: ' + ($SubscriptionName))
  Write-Verbose -Message ('SOL0056-VnetName: ' + ($UseCaseVnetName))
  Write-Verbose -Message ('SOL0056-RegionCode: ' + ($RegionCode))
  Write-Verbose -Message ('SOL0056-SubscriptionCode: ' + ($SubscriptionCode))
  Write-Verbose -Message ('SOL0056-SharedServicesVnetName: ' + ($SharedServicesVnetName))
  Write-Verbose -Message ('SOL0056-RouteTableName: ' + ($RouteTableName))


  #############################################################################################################################################################
  #
  # Create VNET peering - VNET1 -> Shared Services / VNET2 -> Shared Services
  #
  #############################################################################################################################################################
  $Result = PAT0053-NetworkVnetPeeringNew -Vnet1Name $SharedServicesVnetName -Vnet2Name $UseCaseVnetName

  
  #############################################################################################################################################################
  #
  # Configure User Defined Routes in the the Use Case Subscription - route all on-premise traffic to the Virtual Network Gateway 
  #
  #############################################################################################################################################################
  InlineScript
  {
    $AzureAutomationCredential = $Using:AzureAutomationCredential
    $SubscriptionName = $Using:SubscriptionName
    $RouteTableName = $Using:RouteTableName

    $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
    $RouteTable = Get-AzureRmRouteTable | Where-Object {$_.Name -eq $RouteTableName}
    Write-Verbose -Message ('PAT0053-RouteTableVnet1: ' + ($RouteTable | Out-String)) 

    $RouteTable | Add-AzureRmRouteConfig -Name on-premise `                                              -AddressPrefix 10.10.0.0/16 `
                                              -NextHopType 'Virtual network gateway' `
                | Set-AzureRmRouteTable
    Write-Verbose -Message ('SOL0056-RouteTableRoutesAdded: ' + ($RouteTable.Routes | Out-String)) 
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUk3eXFA2C7ny7B/y2R0n0OPyh
# 3eugggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUdOfQer+G+Wgz
# 8O8nOA+U+YMKrc0wDQYJKoZIhvcNAQEBBQAEggEAWSzhLeGLvm1ebgYCgvDR+99+
# DEQLovD34iZMh7eOJ/sj7egch/aNvchG/d4MJpVZWbGhLtrsV+SmwW12iO+wmrXl
# 7/Uw0TGAydIPhgit84lDtvFaZAxGwkaUafcAsHgieKVtz8aVf28kqcqDd2f5Nh2+
# CsYlMRm0Tp7M7Yr6a7hOfQ1n/1J5ekeCfmIV/rOeHainVnwEbReh9PaXvKgS6pLI
# zcU2yTa4Ifv33NZzEJPfONpA5a/BaOzDigNdxt1udGW7aoHwSVFDa4CkUtOfbkdP
# clNLBDsc++y+SaDBGx1GwRjqiYegqQLpkQUlWFPCn8x1arIY7f/+sflcQRjEAg==
# SIG # End signature block
