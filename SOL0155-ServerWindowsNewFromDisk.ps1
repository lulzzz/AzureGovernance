###############################################################################################################################################################
# Creates a VM from an existing Managed Disk. NIC is created, data disks need to be attached manually.
# 
# Output:         none
#
# Template:       SOL0150-ServerWindowsNewFromDisk -VmName $VmName -VmSize $VmSize -ResourceGroupName $ResourceGroupName `
#                                                  -SubscriptionShortName $SubscriptionShortName -SubnetName $SubnetName -Region $Region -OsDiskId $OsDiskId
#
# Requirements:   See Import-Module in code below / Existing Managed Disk
#
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0155-ServerWindowsNewFromDisk
{
  Param
  (
    [Parameter(Mandatory = $false)][String] $VmName = 'w0001',
    [Parameter(Mandatory = $false)][String] $VmSize = 'Basic_A2',
    [Parameter(Mandatory = $false)][String] $ResourceGroupName  = 'weu-co-rsg-automation-01',
    [Parameter(Mandatory = $false)][String] $SubscriptionShortName = 'co',
    [Parameter(Mandatory = $false)][String] $SubnetName = 'weu-co-sub-vnt01-fe',
    [Parameter(Mandatory = $false)][String] $Region = 'West Europe',
    [Parameter(Mandatory = $false)][String] $OsDiskId = '/subscriptions/ae747229-5897-4d01-93bb-284e69893c47/resourceGroups/weu-co-rsg-automation-01/providers/Microsoft.Compute/disks/w0001-osdisk'
  )


  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Compute, AzureRM.Network, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $VmName = $Using:VmName
    $VmSize = $Using:VmSize
    $ResourceGroupName = $Using:ResourceGroupName
    $SubscriptionShortName = $Using:SubscriptionShortName
    $SubnetName = $Using:SubnetName
    $Region = $Using:Region
    $OsDiskId = $Using:OsDiskId
    

    #############################################################################################################################################################
    #
    # Variables
    #
    ############################################################################################################################################################## 
    $CustomerShortCode = Get-AutomationVariable -Name VAR-AUTO-CustomerShortCode
    $RegionCode = $SubnetName.Split('-')[0]

    # Diagnostic account
    $ResourceGroupNameCore = 'aaa-' + $SubscriptionShortName + '-rsg-core-01'
    $DiagnosticsAccountName = $CustomerShortcode + $RegionCode + $SubscriptionShortName + 'diag01s'
  
    #############################################################################################################################################################
    #
    # Change to Subscription where server is to be built
    #
    #############################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('SOL0155-AzureContext: ' + ($AzureContext | Out-String))


    #############################################################################################################################################################
    #  
    # Create NIC
    #
    #############################################################################################################################################################
    $Vnet = Get-AzureRmVirtualNetwork | Where-Object  {$_.Subnets.Name -eq $SubnetName}
    $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet

    $NetworkInterface = New-AzureRmNetworkInterface -Name ($VmName + '-' + $SubnetName.Split('-')[4] + '-01') -ResourceGroupName $ResourceGroupName -Location $Region `
                                                    -SubnetId $Subnet.Id
    Write-Verbose -Message ('SOL0155-NicCreated: ' + ($NetworkInterface | Out-String))


    #############################################################################################################################################################
    #  
    # Create VM
    #
    #############################################################################################################################################################
    $Vm = New-AzureRmVMConfig -VMName $VmName -VMSize $VmSize
    $Vm = Add-AzureRmVMNetworkInterface -VM $Vm -Id $NetworkInterface.Id -Primary
    $Vm = Set-AzureRmVMOSDisk -VM $Vm -Windows -StorageAccountType Standard_LRS -CreateOption Attach -ManagedDiskId $OsDiskId
    $Vm = Set-AzureRmVMBootDiagnostics -Enable -ResourceGroupName $ResourceGroupNameCore -VM $Vm -StorageAccountName $DiagnosticsAccountName
    $Vm = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Region -VM $Vm 
    Write-Verbose -Message ('SOL0155-VmCreated: ' + ($Vm | ConvertTo-Json))
  }
}
