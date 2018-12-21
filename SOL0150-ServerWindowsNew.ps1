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
#
###############################################################################################################################################################
workflow SOL0150-ServerWindowsNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $VmName = 'azw0001',
    [Parameter(Mandatory=$false)][String] $LocationName = 'westeurope',
    [Parameter(Mandatory=$false)][String] $LocationShortName = 'weu',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-co-rsg-automation-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = 'co',
    [Parameter(Mandatory=$false)][String] $SubnetShortName = 'fe',
    [Parameter(Mandatory=$false)][String] $BackupRequired = 'no',
    [Parameter(Mandatory=$false)][String] $PublicIpAddressRequired = 'no',
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
    $Result = Import-Module AzureRM.Compute, AzureRM.Network, AzureRM.profile, AzureRM.RecoveryServices, AzureRM.RecoveryServices.Backup, AzureRM.Resources
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
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
  $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force


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
    $CustomerShortName = 'swi'

    # Resource Groups
    $ResourceGroupNameCore = "$LocationShortName-$SubscriptionShortName-rsg-core-01"
    $ResourceGroupNameNetwork = "$LocationShortName-$SubscriptionShortName-rsg-network-01"

    # VM
    $PublisherName = 'MicrosoftWindowsServer'                                            # 'MicrosoftSqlServer' / 'MicrosoftWindowsServer'
    $OfferName = 'WindowsServer'                                                         # 'SQL2012SP3-WS2012R2'/ 'WindowsServer'  
    $SkuName = '2016-Datacenter'                                                         # 'Standard' / '2012-R2-Datacenter' /'2016-Datacenter'
    $VmSize =  'Basic_A1'                                                                # 'Standard_A2' / 'Standard_DS4_v2' / 'Basic_A1' 

    # NIC
    $VnetName = $LocationShortName + '-' + $SubscriptionShortName + '-vnt-01'
    $SubnetName = $LocationShortName + '-' + $SubscriptionShortName + '-sub-vnt01-' + $SubnetShortName
    $Vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName  $ResourceGroupNameNetwork
    $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    $ServerNicName = $VmName + '-' + $SubnetName.Split('-')[4] + '-01'

    # Storage Account for Diagnostics
    $StorageAccountType = 's'                                                            # p = Premium / s = Standard
    $DiagnosticsAccountName = $CustomerShortName + $LocationShortName + $SubscriptionShortName + 'diag01' + $StorageAccountType

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
        $AvailabilitySetId = (Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName -ErrorAction Stop).Id
        Write-Verbose -Message ('SOL0150-Availability Set existing ' + $AvailabilitySetId) 
      }
      catch
      {
        $AvailabilitySet = New-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName `
                                                      -Name $AvailabilitySetName `
                                                      -Location $LocationName

        # Create tags
        $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
        $Result = Set-AzureRmResource -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName `
                                      -Tag $Tags -ResourceType Microsoft.Compute/availabilitySets -Force

        $AvailabilitySetId = (Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName).Id
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
      $PublicIpAddress = New-AzureRmPublicIpAddress -AllocationMethod Static -ResourceGroupName $ResourceGroupName -IpAddressVersion IPv4 `
                                                    -Location $LocationName -Name "$LocationShortName-$SubscriptionShortName-pub-$VmName-01"

      # Create tags
      $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
      $PublicIpAddress.Tag = $Tags
      $PublicIpAddress = Set-AzureRmPublicIpAddress -PublicIpAddress $PublicIpAddress
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
    $NetworkInterface = New-AzureRmNetworkInterface -Name $ServerNicName -ResourceGroupName $ResourceGroupName -Location $LocationName `
                                                    -SubnetId $Subnet.Id  `
                                                    -PublicIpAddressId $PublicIpAddress.Id -Force -WarningAction SilentlyContinue
    Write-Verbose -Message ('SOL0150-Network Interface created: ' + ($NetworkInterface | Out-String))

    # Create tags
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    $NetworkInterface.Tag = $Tags
    $NetworkInterface = Set-AzureRmNetworkInterface -NetworkInterface $NetworkInterface 
    Write-Verbose -Message ('SOL0150-Network Interface Tags written: ' + ($Tags | Out-String))


    ###########################################################################################################################################################
    #
    # Create the VM object and attach the following to the object: OS disk / Data disk(s) / Admin account & OS type / Disk image / NIC
    #
    ###########################################################################################################################################################
    if ($AvailabilitySetNameRequired -eq 'yes')
    { 
      $Vm = New-AzureRmVMConfig -VMName $VmName -VMSize $VmSize -AvailabilitySetId $AvailabilitySetId
    }
    else
    {
      $Vm = New-AzureRmVMConfig -VMName $VmName -VMSize $VmSize
    }
    # Specify the image and local administrator account
    $Vm = Set-AzureRmVMOperatingSystem -VM $Vm -Windows -ComputerName $VmName -Credential $LocalAdminCredential -ProvisionVMAgent -EnableAutoUpdate
    $Vm = Set-AzureRmVMSourceImage -VM $Vm -PublisherName $PublisherName -Offer $OfferName -Skus $SkuName -Version 'latest'

    # Specify the NIC
    $Vm = Add-AzureRmVMNetworkInterface -VM $Vm -Id $NetworkInterface.Id -Primary

    # Specify the OS disk
    $Vm = Set-AzureRmVMOSDisk -VM $Vm -Name $OsDiskName -StorageAccountType Standard_LRS -CreateOption FromImage -Caching ReadWrite

    # Specify diagnostics location
    $Vm = Set-AzureRmVMBootDiagnostics -Enable -ResourceGroupName $ResourceGroupNameCore -VM $Vm -StorageAccountName $DiagnosticsAccountName


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
        $DiskConfig = New-AzureRmDiskConfig -AccountType $StorageType -Location $LocationName -CreateOption Empty `
                                            -DiskSizeGB $DataDisks.Get_Item(($DataDiskLun+1).ToString('00'))
        $DataDisk = New-AzureRmDisk -DiskName ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -Disk $DiskConfig -ResourceGroupName $ResourceGroupName
        $Vm = Add-AzureRmVMDataDisk -VM $Vm -Name ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -CreateOption Attach -ManagedDiskId $DataDisk.Id `
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
    $Result = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $Vm
    Write-Verbose -Message ('SOL0150-VM created')
 
  
    ###########################################################################################################################################################
    #
    # Create Tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    $Result = Set-AzureRmResource -Name $VmName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Compute/VirtualMachines' -Tag $Tags -Force
    Write-Verbose -Message ('SOL0150-VM Tags created')
 
  
    ###########################################################################################################################################################
    #
    # Configure Azure Backup
    #
    ###########################################################################################################################################################
    if ($BackupRequired -eq 'yes')
    { 
      $BackupVault = Get-AzureRmRecoveryServicesVault -Name $BackupVaultName
      $Result = Set-AzureRmRecoveryServicesVaultContext -Vault $BackupVault
      $BackupPolicy = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicyName
      $Result = Enable-AzureRmRecoveryServicesBackupProtection -Policy $BackupPolicy -Name $VmName -ResourceGroupName $ResourceGroupName
      Write-Verbose -Message ('SOL0150-VM added to Azure Backup')
    }
  }
}
