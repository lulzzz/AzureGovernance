###############################################################################################################################################################
# Creates a default VNET (e.g. weu-0010-vnt-01) in the '-rsg-network-01' Resource Group, IP ranges are retrieved from the Azure Table Ipam
# Creates an empty Route Table for the Frontend Subnet (e.g. weu-0010-rot-routetable-01). 
# Connects the Subnets (weu-0010-sub-vnt01-fe / weu-0010-sub-vnt01-be) to the existing NSGs (weu-0010-nsg-vnt01fe / weu-0010-nsg-vnt01be).
# Configures Service Endpoints for Microsoft.Storage to allow for Storage Account integration into VNET. Tags the VNET and Route Table.
# 
# Output:         $VnetName
#
# Requirements:   See Import-Module in code below / '-rsg-network-01' Resource Group, NSGs
#
# Template:       PAT0050-NetworkVnetNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                        -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact -Automation $Automation
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0050-NetworkVnetNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = '0010',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'Application-001',                                                                                    # Tagging
    [Parameter(Mandatory=$false)][String] $CostCenter = 'A99.2345.34-f',                                                                                         # Tagging
    [Parameter(Mandatory=$false)][String] $Budget = '100',                                                                                                       # Tagging
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com',                                                                                     # Tagging
    [Parameter(Mandatory=$false)][String] $Automation = 'v1.0'                                                                                                   # Tagging
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Network, AzureRM.profile, AzureRM.Resources, AzureRmStorageTable
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet
  

  $VnetName = InlineScript
  { 
    $SubscriptionCode = $Using:SubscriptionCode
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $ApplicationId = $Using:ApplicationId 
    $CostCenter = $Using:CostCenter 
    $Budget = $Using:Budget 
    $Contact = $Using:Contact 
    $Automation = $Using:Automation


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false

    $VnetName = $RegionCode + '-' + $SubscriptionCode + '-vnt-01'                                                                                                # e.g. weu-0010-vnt-01
    $ResourceGroupName = $RegionCode + '-' + $SubscriptionCode + '-rsg-network-01'                                                                               # e.g. weu-0010-rsg-network-01
    
    # Subnets
    $FrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-sub-vnt01-fe'                                                                                # e.g. weu-0010-sub-vnt01-fe
    $BackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-sub-vnt01-be'                                                                                 # e.g. weu-0010-sub-vnt01-be
    
    # Route Table
    $RouteTableName = $RegionCode + '-' + $SubscriptionCode + '-rot-routetable-01'                                                                               # e.g. weu-0010-rot-routetable-01

    # Network Security Groups
    $NsgFrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01fe'                                                                              # e.g. weu-0010-nsg-vnt01fe
    $NsgBackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01be'                                                                               # e.g. weu-0010-nsg-vnt01be
    $ResourceGroupNameNsg = $RegionCode + '-' + $SubscriptionCode + '-rsg-security-01'                                                                           # e.g. weu-0010-rsg-security-01

    Write-Verbose -Message ('PAT0050-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0050-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0050-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0050-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0050-Budget: ' + ($Budget))
    Write-Verbose -Message ('PAT0050-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0050-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0050-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0050-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0050-VnetName: ' + ($VnetName))
    Write-Verbose -Message ('PAT0050-FrontendSubnetName: ' + ($FrontendSubnetName))
    Write-Verbose -Message ('PAT0050-BackendSubnetName: ' + ($BackendSubnetName))
    Write-Verbose -Message ('PAT0050-NsgFrontendSubnetName: ' + ($NsgFrontendSubnetName))
    Write-Verbose -Message ('PAT0050-NsgBackendSubnetName: ' + ($NsgBackendSubnetName))
    Write-Verbose -Message ('PAT0050-ResourceGroupNameNsg: ' + ($ResourceGroupNameNsg))


    ###########################################################################################################################################################
    #
    # Retrieve available VNET and associated Subnet IP address ranges form Azure Table Ipam in the Core Storage Account
    #
    ###########################################################################################################################################################
    $Table = Get-AzureStorageTable -Name Ipam

    # Select first available VNET Range
    $VnetIpRange = (Get-AzureStorageTableRowByColumnName -table $Table -columnName VnetName -value $null -operator Equal | Sort-Object PartitionKey | `
                    Select-Object -First 1).VnetIpRange

    # Get Subnet IP ranges for selected VNET
    $SubnetIpRange = (Get-AzureStorageTableRowByColumnName -table $Table -columnName VnetIpRange -value $VnetIpRange -operator Equal | `
                      Sort-Object SubnetIpRange | Select-Object -Property SubnetIpRange -Unique).SubnetIpRange
    $FrontendSubnetIpRange = $SubnetIpRange[0]
    $BackendSubnetIpRange = $SubnetIpRange[1]

    Write-Verbose -Message ('PAT0050-VnetIpRange: ' + ($VnetIpRange))
    Write-Verbose -Message ('PAT0050-FrontendSubnetIpRange: ' + ($FrontendSubnetIpRange))
    Write-Verbose -Message ('PAT0050-BackendSubnetIpRange: ' + ($BackendSubnetIpRange))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0050-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #  
    # Check if VNET already exists
    #
    ###########################################################################################################################################################
    $Vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Vnet.Length -gt '0')
    {
      Write-Error -Message ('PAT0050-VnetAlreadyExisting: ' + ($Vnet | Out-String))
      Return
    }
    
      
    ###########################################################################################################################################################
    #  
    # Get NSG
    #
    ###########################################################################################################################################################
    # Get NSG for Frontend Subnet
    $NsgFrontendSubnet = Get-AzureRmNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupNameNsg
    Write-Verbose -Message ('PAT0050-NsgFrontSubnetCreated: ' + ($NsgFrontendSubnet | Out-String))

    # Get NSG for Backend Subnet
    $NsgBackendSubnet = Get-AzureRmNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupNameNsg
    Write-Verbose -Message ('PAT0050-NsgBackendSubnetCreated: ' + ($NsgBackendSubnet | Out-String))


    ###########################################################################################################################################################
    #
    # Create Route Table to be assigned to Frontend Subnet
    #
    ###########################################################################################################################################################
    $RouteTable = New-AzureRmRouteTable -Name $RouteTableName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0050-RouteTableCreated: ' + ($RouteTable | Out-String))

       
    ###########################################################################################################################################################
    #  
    # Create VNET with Subnets and a Service Endpoint for Azure Storage (Microsoft.Storage) - assign Route Table to Frontend Subnet
    #
    ###########################################################################################################################################################
    $FrontendSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $FrontendSubnetName -AddressPrefix $FrontendSubnetIpRange -RouteTable $RouteTable `
                                                            -NetworkSecurityGroup $NsgFrontendSubnet -ServiceEndpoint Microsoft.Storage
    Write-Verbose -Message ('PAT0050-FrontendSubnetCreated: ' + ($FrontendSubnet | Out-String))

    $BackendSubnet  = New-AzureRmVirtualNetworkSubnetConfig -Name $BackendSubnetName  -AddressPrefix $BackendSubnetIpRange `
                                                            -NetworkSecurityGroup $NsgBackendSubnet -ServiceEndpoint Microsoft.Storage
    Write-Verbose -Message ('PAT0050-BackendSubnetCreated: ' + ($BackendSubnet | Out-String))

    $Vnet = New-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -Location $RegionName -AddressPrefix $VnetIpRange `
                                      -Subnet $FrontendSubnet, $BackendSubnet
    Write-Verbose -Message ('PAT0050-VnetCreated: ' + ($Vnet | Out-String))


    ###########################################################################################################################################################
    #
    # Create Tags for VNET and Route Table
    #
    ###########################################################################################################################################################
    $Tags = $null
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0050-TagsToWrite: ' + ($Tags | Out-String))

    # VNET
    $Result = Set-AzureRmResource -Name $VnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/virtualNetworks' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0050-VnetTagged: ' + ($VnetName))

    # Route Table
    $Result = Set-AzureRmResource -Name $RouteTableName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/routeTables' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0050-RouteTableTagged: ' + ($VnetName))


    ###########################################################################################################################################################
    #
    # Reserve VNET and associated Subnet IP address ranges retrieved above
    #
    ###########################################################################################################################################################
    TEC0005-AzureContextSet
    $TableEntries = Get-AzureStorageTableRowByColumnName -table $Table -columnName SubnetIpRange -value $FrontendSubnetIpRange -operator Equal
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = $VnetName
      $TableEntry.SubnetName = $FrontendSubnetName
      $Result = $TableEntry | Update-AzureStorageTableRow -table $Table
    }

    $TableEntries = Get-AzureStorageTableRowByColumnName -table $Table -columnName SubnetIpRange -value $BackendSubnetIpRange -operator Equal
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = $VnetName
      $TableEntry.SubnetName = $BackendSubnetName
      $Result = $TableEntry | Update-AzureStorageTableRow -table $Table
    }


    ###########################################################################################################################################################
    #
    # Create CIs
    #
    ###########################################################################################################################################################
    # This has to be added based on the chosen CMDB implementation

    Return $VnetName
  }
  Return $VnetName
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5L40bhMJhySkLr9ovcUGGpA8
# nnugggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUwB+/yFpUFlcr
# d+BaEDoje/xLMCUwDQYJKoZIhvcNAQEBBQAEggEATTw7u0jiIx7sSitWcBuYqtdB
# DtvlW2x6I5dmPALwxpDdKs8pylpxDSHqT2Ux2adBCwytOBsNHG72l7osLVRhH5VA
# /egj1BXvmFr2Mtxbl1na2V+gPru+Vhzp8n4arLd9IyB9UeM/W2E67mvWhsWGNqvF
# AsQJqJyIKHBsVhWiWpVTOiJsqROz7/0cH3ZR4AkSQ9tCxUtBf4sDE3DA2CfeejnE
# cmYeCyQyTxgMHrsigxFJY5IZulMrEsAxHrPSN4kq/ImjD9hNV7vwiRydmq0Yjw2c
# q/gYYa01q+B9Iwria2igXuiOXNRyDLtt0vLju8QSKJmgCF1yVNGjoMhhExIb6w==
# SIG # End signature block
