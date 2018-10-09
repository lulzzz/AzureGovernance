###############################################################################################################################################################
# Creates a new server based on the input parameters.
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   ???
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0001-CreateServer
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $VmName = 'w0002',
    [Parameter(Mandatory=$false)][String] $LocationName = 'westus',
    [Parameter(Mandatory=$false)][String] $LocationShortName = 'wus',
    [Parameter(Mandatory=$false)][String] $RgIndividualName = 'filesync',
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = 'te'
  )

  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext

  # Credentials and groups for local non-domain joined Windows admin
  $LocalAdminCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-LocalAdminUser'

  InlineScript
  {
    $VmName = $Using:VmName
    $LocationName = $Using:LocationName
    $LocationShortName = $Using:LocationShortName 
    $RgIndividualName = $Using:RgIndividualName
    $SubscriptionShortName = $Using:SubscriptionShortName
    $LocalAdminCredential = $Using:LocalAdminCredential

    ##################################################################################################################################################################################
    #
    # Variables
    #
    ##################################################################################################################################################################################
    # Basic
    $CustomerShortName = 'fel'

    # Resource Groups
    $RgName = "$LocationShortName-$SubscriptionShortName-rg-$RgIndividualName-" + '01'
    $RgNameCore = "$LocationShortName-$SubscriptionShortName-rg-core-01"

    # VM
    $PublisherName = 'MicrosoftWindowsServer'                                            # 'MicrosoftSqlServer' / 'MicrosoftWindowsServer'
    $OfferName = 'WindowsServer'                                                         # 'SQL2012SP3-WS2012R2'/ 'WindowsServer'  
    $SkuName = '2016-Datacenter'                                                      # 'Standard' / '2012-R2-Datacenter' / '2016-Datacenter'
    $VmSize =  'Basic_A1'                                                                # 'Standard_A2' / 'Standard_DS4_v2' / 'Basic_A1' 

    # NIC
    $PublicIpAddressRequired = $False
    $VnetName = $LocationShortName + '-' + $SubscriptionShortName + '-vnet-01'
    $SubnetName = $LocationShortName + '-' + $SubscriptionShortName + '-sub-vnet01-fe'
    $Vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $RgNameCore
    $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    $ServerNicName = $VmName + '-' + $SubnetName.Split('-')[4] + '-01'
    $AddressRange = ($Subnet.AddressPrefix -Split '.0/')[0] + '.'

    # Storage Accounts
    $StorageAccountType = 's'                                                            # p = Premium / s = Standard
    $DiagnosticsAccountName = $CustomerShortName + $LocationShortName + $SubscriptionShortName + 'diag01' + $StorageAccountType

    # OS Disk
    $OsDiskName = ($VmName + '-osdisk')

    # Backup
    $BackupRequired = $false 
    $BackupVaultName = $LocationShortName + $SubscriptionShortName + '-bkp-gsrvault-01'
    $BackupPolicyName = $LocationShortName + $SubscriptionShortName + '-bkp-gsrvault-01-default'

    # Availability Set
    $AvailabilitySetNameRequired = $false
    $AvailabilitySetName = $LocationShortName + '-' + $SubscriptionShortName + '-avs-' + $RgIndividualName + '-01'

    # Tags
    $Allocation = 'Shared'
    $AllocationGroup = 'AE&O'
    $Project = 'Automation'
    $ServiceLevel = 'Sandpit'
    $BillTo = 'I100.35000.00.10.00'

    # Data Disk(s) - disk number and disk size in GB (do not exceed 1023 GB per disk)
    $DataDisksRequired = $false 
    $StorageType = 'Standard_LRS'
    $DataDisks = @{'01' = '1023'}                                    # Always assign 1023 GB for standard storage accounts
    $DataDisks = $DataDisks.GetEnumerator() | Sort-Object Name

    ##################################################################################################################################################################################
    #
    # Check if Availability Set is required. If required check if existing and if not create
    #
    ##################################################################################################################################################################################
    if ($AvailabilitySetNameRequired)
    { 
      try
      {
        $AvailabilitySetId = (Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName -ErrorAction Stop).Id
        Write-Verbose -Message ('SOL0001-Availability Set existing ' + $AvailabilitySetId) 
      }
      catch
      {
        $AvailabilitySet = New-AzureRmAvailabilitySet -ResourceGroupName $RgName `
                                                      -Name $AvailabilitySetName `
                                                      -Location $LocationName

        # Create tags
        $Tags = $null
        $Tags = @{Allocation = $Allocation; AllocationGroup = $AllocationGroup; Project = $Project; ServiceLevel = $ServiceLevel; BillTo = $BillTo}

        $Result = Set-AzureRmResource -ResourceGroupName $RgName -Name $AvailabilitySetName -Tag $Tags -ResourceType Microsoft.Compute/availabilitySets -Force

        $AvailabilitySetId = (Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName).Id
        Write-Verbose -Message ('SOL0001-New Availability Set created ' + $AvailabilitySetId) 
      }
    }
    else
    {
      Write-Verbose -Message ('SOL0001-Availability Set not required')
    }
  
    ##################################################################################################################################################################################
    #
    # Retrieve private IP address
    #
    ##################################################################################################################################################################################
    # Retrieve the IP addresses used for NIC and LLB
    $VmNic = Get-AzureRmNetworkInterface | Where-Object {$_.IpConfigurations.PrivateIpAddress -match $AddressRange} 
    $LlbNic = Get-AzureRmLoadBalancer | Where-Object  {$_.FrontendIpConfigurations.PrivateIpAddress -match $AddressRange}

    # Extract the last part of all retrieved IP addresses
    $IpAddresses = @()
    if($VmNic)
    {
      $IpAddresses = $IpAddresses + ($VmNic.IpConfigurations.PrivateIpAddress).Replace($AddressRange, '')
    }
    if($LlbNic)
    {
      $IpAddresses = $IpAddresses + ($LlbNic.FrontendIpConfigurations.PrivateIpAddress).Replace($AddressRange, '')
    }

    # Sort last part of IP address to determine first available address - bypass if none have been retrieved above 
    if($IpAddresses)
    { 
      $IpAddresses = foreach ($item in $IpAddresses)
      {
        [int]$item = $item
        $item.ToString('000')
      }
      [array]::Sort($IpAddresses)
      $PrivateIpAddress = $AddressRange + ([int]($IpAddresses[$IpAddresses.length-1])+1)
      Write-Verbose -Message ('SOL0001-Private Ip address selected: ' + $PrivateIpAddress)
    }
  
    ##################################################################################################################################################################################
    #
    # Retrieve public IP address 
    #
    ##################################################################################################################################################################################
    if ($PublicIpAddressRequired)
    { 
      $PublicIpAddress = New-AzureRmPublicIpAddress -AllocationMethod Static -ResourceGroupName $RgName -IpAddressVersion IPv4 -Location $LocationName `
                                                    -Name "$LocationShortName-$SubscriptionShortName-pub-$VmName-01"

      # Create tags
      $Tags = $null             
      $Tags = @{Allocation = $Allocation; AllocationGroup = $AllocationGroup; Project = $Project; ServiceLevel = $ServiceLevel; BillTo = $BillTo}


        $PublicIpAddress.Tag = $Tags
        $PublicIpAddress = Set-AzureRmPublicIpAddress -PublicIpAddress $PublicIpAddress
      Write-Verbose -Message ('SOL0001-Network Interface Tags written: ' + ($Tags | Out-String))
    }
    else
    {
      Write-Verbose -Message ('SOL0001-Public IP address not required')
    }

    ##################################################################################################################################################################################
    #
    # Create network interface
    #
    ##################################################################################################################################################################################
    $NetworkInterface = New-AzureRmNetworkInterface -Name $ServerNicName -ResourceGroupName $RgName -Location $LocationName `
                                                    -SubnetId $Subnet.Id -PrivateIpAddress $PrivateIpAddress `
                                                    -PublicIpAddressId $PublicIpAddress.Id -Force -WarningAction SilentlyContinue
    Write-Verbose -Message ('SOL0001-Network Interface created: ' + ($NetworkInterface | Out-String))

    # Create tags
    $Tags = $null             
    $Tags = @{Allocation = $Allocation; AllocationGroup = $AllocationGroup; Project = $Project; ServiceLevel = $ServiceLevel; BillTo = $BillTo}

    $NetworkInterface.Tag = $Tags
    $NetworkInterface = Set-AzureRmNetworkInterface -NetworkInterface $NetworkInterface 
    Write-Verbose -Message ('SOL0001-Network Interface Tags written: ' + ($Tags | Out-String))

    ##################################################################################################################################################################################
    #
    # Create the VM object and attach the following to the object: OS disk / Data disk(s) / Admin account & OS type / Disk image / NIC
    #
    ################################################################################################################################################################################## 
    if ($AvailabilitySetNameRequired)
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
    $Vm = Set-AzureRmVMOSDisk -VM $Vm -Name $OsDiskName -DiskSizeInGB 127 -StorageAccountType Standard_LRS -CreateOption FromImage -Caching ReadWrite

    # Specify diagnostics location
    $Vm = Set-AzureRmVMBootDiagnostics -Enable -ResourceGroupName $RgNameCore -VM $Vm -StorageAccountName $DiagnosticsAccountName

    ##################################################################################################################################################################################
    #
    # Specify data disk(s) - optional
    #
    ##################################################################################################################################################################################
    if ($DataDisksRequired)
    { 
      $DataDiskLun = 0
      foreach ($Disk in $DataDisks.GetEnumerator())
      {
        $DiskConfig = New-AzureRmDiskConfig -AccountType $StorageType -Location $LocationName -CreateOption Empty -DiskSizeGB $DataDisks.Get_Item(($DataDiskLun+1).ToString('00'))
        $DataDisk = New-AzureRmDisk -DiskName ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -Disk $DiskConfig -ResourceGroupName $RgName
        $Vm = Add-AzureRmVMDataDisk -VM $Vm -Name ($VmName + '-datadisk' + ($DataDiskLun+1).ToString('00')) -CreateOption Attach -ManagedDiskId $DataDisk.Id -Lun $DataDiskLun
        $DataDiskLun ++
      }
    }
    else
    {
      Write-Verbose -Message ('SOL0001-Data disks not required')
    }

    ##################################################################################################################################################################################
    #
    # Create VM
    #
    ##################################################################################################################################################################################
    Write-Verbose -Message ('SOL0001-VM creation started')
    New-AzureRmVM -ResourceGroupName $RgName -Location $LocationName -VM $Vm
    Write-Verbose -Message ('SOL0001-VM created')
  
    ##################################################################################################################################################################################
    #
    # Create Tags
    #
    ##################################################################################################################################################################################
    $Tags = $null
    $Tags = @{Allocation = $Allocation; Allocation_Group = $AllocationGroup; Project = $Project; Service_Level = $ServiceLevel; Bill_To = $BillTo}

    $Result = Set-AzureRmResource -Name $VmName -ResourceGroupName $RgName -ResourceType 'Microsoft.Compute/VirtualMachines' -Tag $Tags -Force
    Write-Verbose -Message ('SOL0001-VM Tags created')
  
    ##################################################################################################################################################################################
    #
    # Configure Azure Backup
    #
    ##################################################################################################################################################################################
    if ($BackupRequired)
    { 
      $BackupVault = Get-AzureRmRecoveryServicesVault -Name $BackupVaultName
      Set-AzureRmRecoveryServicesVaultContext -Vault $BackupVault
      $BackupPolicy = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicyName
      Enable-AzureRmRecoveryServicesBackupProtection -Policy $BackupPolicy -Name $VmName -ResourceGroupName $RgName
      Write-Verbose -Message ('SOL0001-VM added to Azure Backup')
    }
  }

  ##################################################################################################################################################################################
  #
  # Storage Configuration - execute locally on server
  #
  ##################################################################################################################################################################################
  InlineScript
  { 
    #Remove (unmount) DVD drive letter
    $Drive = Get-WmiObject win32_logicaldisk -filter 'DriveType=5'
    mountvol.exe $Drive.DeviceID /D
    Write-Verbose -Message 'SOL0001-Removed (unmount) DVD drive letter'

    # Remove (unmount) A: drive letter
    $Drive = Get-WmiObject win32_logicaldisk -filter 'DriveType=2'
    mountvol.exe $Drive.DeviceID /D
    Write-Verbose -Message 'SOL0001-Removed (unmount) A: drive letter'

    # Create data volumes
    $Disks = Get-Disk | Where-Object {$_.PartitionStyle -eq 'Raw'}
    foreach ($Disk in $Disks)
    {
      Set-Disk -Number $Disk.Number -isOffline $false 
      Set-Disk -Number $Disk.Number -isReadOnly $false 
      Initialize-Disk -Number $Disk.Number
      Start-Sleep -Seconds 5
      $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -AssignDriveLetter 
      Start-Sleep -Seconds 5
      Format-Volume -DriveLetter $Partition.DriveLetter -FileSystem NTFS -NewFileSystemLabel 'Data' -Confirm:$false
    }
    Write-Verbose -Message 'SOL0001-Created data volumes'
  } -PSComputerName $VmName -PSCredential $LocalAdminCredential
}
