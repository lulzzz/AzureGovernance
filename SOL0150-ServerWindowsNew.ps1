###############################################################################################################################################################
# Creates a new server based on the input parameters. Optionally a Public IP, Availability Sets, Data Disks and Backup can be configured.
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow SOL0150-ServerWindowsNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $VmName = 'azw1234',
    [Parameter(Mandatory=$false)][String] $LocationName = 'westeurope',
    [Parameter(Mandatory=$false)][String] $LocationShortName = 'weu',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-te-rsg-test-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = 'te',
    [Parameter(Mandatory=$false)][String] $SubnetShortName = 'fe',
    [Parameter(Mandatory=$false)][String] $BackupRequired = 'no',
    [Parameter(Mandatory=$false)][String] $PublicIpAddressRequired = 'yes',
    [Parameter(Mandatory=$false)][String] $AvailabilitySetNameRequired = 'no',
    [Parameter(Mandatory=$false)][String] $DataDisksRequired = 'no',
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
    $Result = Import-Module Az.Compute, Az.Network, Az.Accounts, Az.RecoveryServices, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #
  # Get variables in Subscription of Automation Account
  #
  #############################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false

  # Credentials and groups for local non-domain joined Windows admin
  $LocalAdminCredential = Get-AutomationPSCredential -Name CRE-AUTO-LocalAdminUser


  #############################################################################################################################################################
  #
  # Change to Subscription where server is to be built
  #
  #############################################################################################################################################################
  $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
  $AzureAccount = Set-AzContext -Subscription $Subscription.Name -Force


  InlineScript
  {
    $VmName = $Using:VmName
    $LocationName = $Using:LocationName
    $LocationShortName = $Using:LocationShortName 
    $ResourceGroupName = $Using:ResourceGroupName
    $SubscriptionShortName = $Using:SubscriptionShortName
    $SubnetShortName=$Using:SubnetShortName
    $BackupRequired = $Using:BackupRequired
    $PublicIpAddressRequired =$Using:PublicIpAddressRequired
    $AvailabilitySetNameRequired = $Using:AvailabilitySetNameRequired
    $DataDisksRequired = $Using:DataDisksRequired
    $ApplicationId = $Using:ApplicationId
    $CostCenter = $Using:CostCenter
    $Budget = $Using:Budget
    $Contact = $Using:Contact
    $Automation = $Using:Automation
    $LocalAdminCredential = $Using:LocalAdminCredential


    ###########################################################################################################################################################
    #
    # Variables
    #
    ###########################################################################################################################################################
    # Basic
    $CustomerShortCode = Get-AutomationVariable -Name VAR-AUTO-CustomerShortCode

    # Resource Groups
    $ResourceGroupNameCore = "aaa-$SubscriptionShortName-rsg-core-01"
    $ResourceGroupNameNetwork = "aaa-$SubscriptionShortName-rsg-network-01"

    # VM
    $PublisherName = 'MicrosoftWindowsServer'                                            # 'MicrosoftSqlServer' / 'MicrosoftWindowsServer'
    $OfferName = 'WindowsServer'                                                         # 'SQL2012SP3-WS2012R2'/ 'WindowsServer'  
    $SkuName = '2016-Datacenter'                                                         # 'Standard' / '2012-R2-Datacenter' /'2016-Datacenter'
    $VmSize =  'Basic_A1'                                                                # 'Standard_A2' / 'Standard_DS4_v2' / 'Basic_A1' 

    # NIC
    $VnetName = $LocationShortName + '-' + $SubscriptionShortName + '-vnt-01'
    $SubnetName = $LocationShortName + '-' + $SubscriptionShortName + '-sub-vnt01-' + $SubnetShortName
    $Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName  $ResourceGroupNameNetwork
    $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    $ServerNicName = $VmName + '-' + $SubnetName.Split('-')[4] + '-01'

    # Storage Account for Diagnostics
    $StorageAccountType = 's'                                                            # p = Premium / s = Standard
    $DiagnosticsAccountName = $CustomerShortCode + $LocationShortName + $SubscriptionShortName + 'diag01' + $StorageAccountType

    # OS Disk
    $OsDiskName = ($VmName + '-osdisk')

    # Backup
    $BackupVaultName = $LocationShortName + $SubscriptionShortName + '-bkp-gsrvault-01'
    $BackupPolicyName = $LocationShortName + $SubscriptionShortName + '-bkp-gsrvault-01-default'

    # Availability Set
    $AvailabilitySetName = $LocationShortName + '-' + $SubscriptionShortName + '-avs-' + 'test' + '-01'

    # Data Disk(s) - disk number and disk size in GB (do not exceed 1023 GB per disk)
    $StorageType = 'Standard_LRS'
    $DataDisks = @{'01' = '1023'}                                    # Always assign 1023 GB for standard storage accounts
    $DataDisks = $DataDisks.GetEnumerator() | Sort-Object Name

    Write-Verbose -Message ('SOL0150-LocationName: ' + ($LocationName | Out-String))
    Write-Verbose -Message ('SOL0150-LocationShortName: ' + ($LocationShortName | Out-String))
    Write-Verbose -Message ('SOL0150-ResourceGroupName: ' + ($ResourceGroupName | Out-String))
    Write-Verbose -Message ('SOL0150-SubscriptionShortName: ' + ($SubscriptionShortName | Out-String))
    Write-Verbose -Message ('SOL0150-SubnetShortName: ' + ($SubnetShortName | Out-String))
    Write-Verbose -Message ('SOL0150-ApplicationId: ' + ($ApplicationId | Out-String))
    Write-Verbose -Message ('SOL0150-CostCenter: ' + ($CostCenter | Out-String))
    Write-Verbose -Message ('SOL0150-Budget: ' + ($Budget | Out-String))
    Write-Verbose -Message ('SOL0150-Contact: ' + ($Contact | Out-String))
    Write-Verbose -Message ('SOL0150-Automation: ' + ($Automation | Out-String))
    Write-Verbose -Message ('SOL0150-ResourceGroupNameCore: ' + ($ResourceGroupNameCore | Out-String))
    Write-Verbose -Message ('SOL0150-ResourceGroupNameNetwork: ' + ($ResourceGroupNameNetwork | Out-String))
    Write-Verbose -Message ('SOL0150-PublisherName: ' + ($PublisherName | Out-String))
    Write-Verbose -Message ('SOL0150-OfferName: ' + ($OfferName | Out-String))
    Write-Verbose -Message ('SOL0150-SkuName: ' + ($SkuName | Out-String))
    Write-Verbose -Message ('SOL0150-VmSize: ' + ($VmSize | Out-String))
    Write-Verbose -Message ('SOL0150-PublicIpAddressRequired: ' + ($PublicIpAddressRequired | Out-String))
    Write-Verbose -Message ('SOL0150-Vnet: ' + ($Vnet | Out-String))
    Write-Verbose -Message ('SOL0150-Subnet: ' + ($Subnet | Out-String))
    Write-Verbose -Message ('SOL0150-ServerNicName: ' + ($ServerNicName | Out-String))
    Write-Verbose -Message ('SOL0150-DiagnosticsAccountName: ' + ($DiagnosticsAccountName | Out-String))
    Write-Verbose -Message ('SOL0150-BackupRequired: ' + ($BackupRequired | Out-String))
    Write-Verbose -Message ('SOL0150-BackupVaultName: ' + ($BackupVaultName | Out-String))
    Write-Verbose -Message ('SOL0150-BackupPolicyName: ' + ($BackupPolicyName | Out-String))
    Write-Verbose -Message ('SOL0150-AvailabilitySetNameRequired: ' + ($AvailabilitySetNameRequired | Out-String))
    Write-Verbose -Message ('SOL0150-AvailabilitySetName: ' + ($AvailabilitySetName | Out-String))
    Write-Verbose -Message ('SOL0150-DataDisksRequired: ' + ($DataDisksRequired | Out-String))
    Write-Verbose -Message ('SOL0150-DataDisks: ' + ($DataDisks | Out-String))


    ###########################################################################################################################################################
    #
    # Check if Availability Set is required. If required check if existing and if not create
    #
    ###########################################################################################################################################################
    if ($AvailabilitySetNameRequired -eq 'yes')
    { 
      try
      {
        $AvailabilitySetId = (Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName -ErrorAction Stop).Id
        Write-Verbose -Message ('SOL0150-Availability Set existing ' + $AvailabilitySetId) 
      }
      catch
      {
        $AvailabilitySet = New-AzAvailabilitySet -ResourceGroupName $ResourceGroupName `
                                                      -Name $AvailabilitySetName `
                                                      -Location $LocationName

        # Create tags
        $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
        $Result = Set-AzResource -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName `
                                      -Tag $Tags -ResourceType Microsoft.Compute/availabilitySets -Force

        $AvailabilitySetId = (Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName).Id
        Write-Verbose -Message ('SOL0150-New Availability Set created ' + $AvailabilitySetId) 
      }
    }
    else
    {
      Write-Verbose -Message ('SOL0150-Availability Set not required')
    }
  

    ###########################################################################################################################################################
    #
    # Retrieve public IP address 
    #
    ###########################################################################################################################################################
    if ($PublicIpAddressRequired -eq 'yes')
    { 
      $PublicIpAddress = New-AzPublicIpAddress -AllocationMethod Static -ResourceGroupName $ResourceGroupName -IpAddressVersion IPv4 `
                                                    -Location $LocationName -Name "$LocationShortName-$SubscriptionShortName-pub-$VmName-01"

      # Create tags
      $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
      $PublicIpAddress.Tag = $Tags
      $PublicIpAddress = Set-AzPublicIpAddress -PublicIpAddress $PublicIpAddress
      Write-Verbose -Message ('SOL0150-Network Interface Tags written: ' + ($Tags | Out-String))
    }
    else
    {
      Write-Verbose -Message ('SOL0150-Public IP address not required')
    }

  
    ###########################################################################################################################################################
    #
    # Create network interface
    #
    ###########################################################################################################################################################
    $NetworkInterface = New-AzNetworkInterface -Name $ServerNicName -ResourceGroupName $ResourceGroupName -Location $LocationName `
                                                    -SubnetId $Subnet.Id  `
                                                    -PublicIpAddressId $PublicIpAddress.Id -Force -WarningAction SilentlyContinue
    Write-Verbose -Message ('SOL0150-Network Interface created: ' + ($NetworkInterface | Out-String))

    # Create tags
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    $NetworkInterface.Tag = $Tags
    $NetworkInterface = Set-AzNetworkInterface -NetworkInterface $NetworkInterface 
    Write-Verbose -Message ('SOL0150-Network Interface Tags written: ' + ($Tags | Out-String))


    ###########################################################################################################################################################
    #
    # Create the VM object and attach the following to the object: OS disk / Data disk(s) / Admin account & OS type / Disk image / NIC
    #
    ###########################################################################################################################################################
    if ($AvailabilitySetNameRequired -eq 'yes')
    { 
      $Vm = New-AzVMConfig -VMName $VmName -VMSize $VmSize -AvailabilitySetId $AvailabilitySetId
    }
    else
    {
      $Vm = New-AzVMConfig -VMName $VmName -VMSize $VmSize
    }
    # Specify the image and local administrator account
    $Vm = Set-AzVMOperatingSystem -VM $Vm -Windows -ComputerName $VmName -Credential $LocalAdminCredential -ProvisionVMAgent -EnableAutoUpdate
    $Vm = Set-AzVMSourceImage -VM $Vm -PublisherName $PublisherName -Offer $OfferName -Skus $SkuName -Version 'latest'

    # Specify the NIC
    $Vm = Add-AzVMNetworkInterface -VM $Vm -Id $NetworkInterface.Id -Primary

    # Specify the OS disk
    $Vm = Set-AzVMOSDisk -VM $Vm -Name $OsDiskName -StorageAccountType Standard_LRS -CreateOption FromImage -Caching ReadWrite

    # Specify diagnostics location
    $Vm = Set-AzVMBootDiagnostics -Enable -ResourceGroupName $ResourceGroupNameCore -VM $Vm -StorageAccountName $DiagnosticsAccountName


    ###########################################################################################################################################################
    #
    # Specify data disk(s) - optional
    #
    ###########################################################################################################################################################
    if ($DataDisksRequired -eq 'yes')
    { 
      $DataDiskLun = 0
      foreach ($Disk in $DataDisks.GetEnumerator())
      {
        $DiskConfig = New-AzDiskConfig -AccountType $StorageType -Location $LocationName -CreateOption Empty `
                                            -DiskSizeGB $DataDisks.Get_Item(($DataDiskLun+1).ToString('00'))
        $DataDisk = New-AzDisk -DiskName ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -Disk $DiskConfig -ResourceGroupName $ResourceGroupName
        $Vm = Add-AzVMDataDisk -VM $Vm -Name ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -CreateOption Attach -ManagedDiskId $DataDisk.Id `
                                    -Lun $DataDiskLun
        $DataDiskLun ++
      }
    }
    else
    {
      Write-Verbose -Message ('SOL0150-Data disks not required')
    }


    ###########################################################################################################################################################
    #
    # Create VM
    #
    ###########################################################################################################################################################
    Write-Verbose -Message ('SOL0150-VM creation started')
    $Result = New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $Vm
    Write-Verbose -Message ('SOL0150-VM created')
 
  
    ###########################################################################################################################################################
    #
    # Create Tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    $Result = Set-AzResource -Name $VmName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Compute/VirtualMachines' -Tag $Tags -Force
    Write-Verbose -Message ('SOL0150-VM Tags created')
 
  
    ###########################################################################################################################################################
    #
    # Configure Azure Backup
    #
    ###########################################################################################################################################################
    if ($BackupRequired -eq 'yes')
    { 
      $BackupVault = Get-AzRecoveryServicesVault -Name $BackupVaultName
      $Result = Set-AzRecoveryServicesVaultContext -Vault $BackupVault
      $BackupPolicy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $BackupPolicyName
      $Result = Enable-AzRecoveryServicesBackupProtection -Policy $BackupPolicy -Name $VmName -ResourceGroupName $ResourceGroupName
      Write-Verbose -Message ('SOL0150-VM added to Azure Backup')
    }
  }
}

