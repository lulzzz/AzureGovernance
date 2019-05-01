###############################################################################################################################################################
# Creates a default VNET (e.g. weu-te-vnt-01) in the '-rsg-network-01' Resource Group, IP ranges are retrieved from the Azure Table Ipam
# Creates an empty Route Table for the Frontend Subnet (e.g. weu-te-rot-routetable-01). 
# Connects the Subnets (weu-te-sub-vnt01-fe / weu-te-sub-vnt01-be) to the existing NSGs (weu-te-nsg-vnt01fe / weu-te-nsg-vnt01be).
# Configures Service Endpoints for Microsoft.Storage to allow for Storage Account integration into VNET. Tags the VNET and Route Table.
# 
# Output:         $VnetName
#
# Requirements:   See Import-Module in code below / '-rsg-network-01' Resource Group, NSGs
#
# Template:       PAT0050-NetworkVnetNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode -Contact $Contact
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0050-NetworkVnetNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'co',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'                                                                                     # Tagging
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
  

  $VnetName = InlineScript
  { 
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

    $VnetName = $RegionCode + '-' + $SubscriptionCode + '-vnt-01'                                                                                                # e.g. weu-te-vnt-01
    $ResourceGroupName = 'aaa-' + $SubscriptionCode + '-rsg-network-01'                                                                                          # e.g. weu-te-rsg-network-01
    
    # Subnets
    $FrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-sub-vnt01-fe'                                                                                # e.g. weu-te-sub-vnt01-fe
    $BackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-sub-vnt01-be'                                                                                 # e.g. weu-te-sub-vnt01-be
    
    # Route Table
    $RouteTableName = $RegionCode + '-' + $SubscriptionCode + '-rot-routetable-01'                                                                               # e.g. weu-te-rot-routetable-01

    # Network Security Groups
    $NsgFrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01fe'                                                                              # e.g. weu-te-nsg-vnt01fe
    $NsgBackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01be'                                                                               # e.g. weu-te-nsg-vnt01be
    $ResourceGroupNameNsg = 'aaa-' + $SubscriptionCode + '-rsg-security-01'                                                                                      # e.g. weu-te-rsg-security-01

    # Set Storage Context
    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName
    $StorageAccount = Get-AzStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.StorageAccountName).Value[0]
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

    Write-Verbose -Message ('PAT0050-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0050-RegionName: ' + ($RegionName))
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
    $Table = (Get-AzStorageTable -Name Ipam -Context $StorageContext).CloudTable

    # Select first available VNET Range
    $VnetIpRange = (Get-AzTableRowByColumnName -table $Table -columnName VnetName -value $null -operator Equal | Sort-Object PartitionKey | `
                    Select-Object -First 1).VnetIpRange

    # Get Subnet IP ranges for selected VNET
    $SubnetIpRange = (Get-AzTableRowByColumnName -table $Table -columnName VnetIpRange -value $VnetIpRange -operator Equal | `
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
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0050-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #  
    # Check if VNET already exists
    #
    ###########################################################################################################################################################
    $Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
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
    $NsgFrontendSubnet = Get-AzNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupNameNsg
    Write-Verbose -Message ('PAT0050-NsgFrontSubnetCreated: ' + ($NsgFrontendSubnet | Out-String))

    # Get NSG for Backend Subnet
    $NsgBackendSubnet = Get-AzNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupNameNsg
    Write-Verbose -Message ('PAT0050-NsgBackendSubnetCreated: ' + ($NsgBackendSubnet | Out-String))


    ###########################################################################################################################################################
    #
    # Create Route Table to be assigned to Frontend Subnet
    #
    ###########################################################################################################################################################
    $RouteTable = New-AzRouteTable -Name $RouteTableName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0050-RouteTableCreated: ' + ($RouteTable | Out-String))

       
    ###########################################################################################################################################################
    #  
    # Create VNET with Subnets and a Service Endpoint for Az.Storage (Microsoft.Storage) - assign Route Table to Frontend Subnet
    #
    ###########################################################################################################################################################
    $FrontendSubnet = New-AzVirtualNetworkSubnetConfig -Name $FrontendSubnetName -AddressPrefix $FrontendSubnetIpRange -RouteTable $RouteTable `
                                                            -NetworkSecurityGroup $NsgFrontendSubnet -ServiceEndpoint Microsoft.Storage
    Write-Verbose -Message ('PAT0050-FrontendSubnetCreated: ' + ($FrontendSubnet | Out-String))

    $BackendSubnet  = New-AzVirtualNetworkSubnetConfig -Name $BackendSubnetName  -AddressPrefix $BackendSubnetIpRange `
                                                            -NetworkSecurityGroup $NsgBackendSubnet -ServiceEndpoint Microsoft.Storage
    Write-Verbose -Message ('PAT0050-BackendSubnetCreated: ' + ($BackendSubnet | Out-String))

    $Vnet = New-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -Location $RegionName -AddressPrefix $VnetIpRange `
                                      -Subnet $FrontendSubnet, $BackendSubnet
    Write-Verbose -Message ('PAT0050-VnetCreated: ' + ($Vnet | Out-String))


    ###########################################################################################################################################################
    #
    # Create Tags for VNET and Route Table
    #
    ###########################################################################################################################################################
    $Tags = $null
    $Tags = @{Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0050-TagsToWrite: ' + ($Tags | Out-String))

    # VNET
    $Result = Set-AzResource -Name $VnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/virtualNetworks' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0050-VnetTagged: ' + ($VnetName))

    # Route Table
    $Result = Set-AzResource -Name $RouteTableName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/routeTables' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0050-RouteTableTagged: ' + ($VnetName))


    ###########################################################################################################################################################
    #
    # Reserve VNET and associated Subnet IP address ranges retrieved above
    #
    ###########################################################################################################################################################
    $TableEntries = Get-AzTableRow -table $Table -columnName SubnetIpRange -value $FrontendSubnetIpRange -operator Equal
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = $VnetName
      $TableEntry.SubnetName = $FrontendSubnetName
      $Result = $TableEntry | Update-AzTableRow -table $Table
    }

    $TableEntries = Get-AzTableRow -table $Table -columnName SubnetIpRange -value $BackendSubnetIpRange -operator Equal
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = $VnetName
      $TableEntry.SubnetName = $BackendSubnetName
      $Result = $TableEntry | Update-AzTableRow -table $Table
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

