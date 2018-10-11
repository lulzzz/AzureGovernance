###############################################################################################################################################################
# Creates a new Linux server based on the input parameters.
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
workflow SOL0160-ServerLinuxNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $VmName = 'razlvdns02',
    [Parameter(Mandatory=$false)][String] $LocationName = 'westeurope',
    [Parameter(Mandatory=$false)][String] $LocationShortName = 'weu',
    [Parameter(Mandatory=$false)][String] $AppId = 'refdns',
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = '0005',
    [Parameter(Mandatory=$false)][String] $SubnetShortName = 'mg'
  )

  $VerbosePreference ='Continue'

  ##################################################################################################################################################################################
  #
  # Get variables in Subscription of Automation Account
  #
  ##################################################################################################################################################################################
  TEC0005-SetAzureContext
  $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false

  # Credentials and groups for local non-domain joined Windows admin
  $LocalAdminCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-LocalAdminUser' -Verbose:$false

  ##################################################################################################################################################################################
  #
  # Change to Subscription where server is to be built
  #
  ##################################################################################################################################################################################
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
  $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force


  InlineScript
  {
    $VmName = $Using:VmName
    $LocationName = $Using:LocationName
    $LocationShortName = $Using:LocationShortName 
    $AppId = $Using:AppId
    $SubscriptionShortName = $Using:SubscriptionShortName
    $LocalAdminCredential = $Using:LocalAdminCredential
    $SubnetShortName=$Using:SubnetShortName

    ##################################################################################################################################################################################
    #
    # Variables
    #
    ##################################################################################################################################################################################
    # Basic
    $CustomerShortName = 'roc'

    # Resource Groups
    $RgName = "$LocationShortName-$SubscriptionShortName-rsg-$AppId-" + '01'
    $RgNameCore = "$LocationShortName-$SubscriptionShortName-rsg-refcore-01"
    $RgNameNetwork = "$LocationShortName-$SubscriptionShortName-rsg-refnet-01"

    # VM
    $PublisherName = 'RedHat'
    $OfferName = 'RHEL'
    $SkuName = '7-RAW'
    $VmSize =  'Standard_B1S'

    # NIC
    $PublicIpAddressRequired = $False
    $VnetName = $LocationShortName + '-' + $SubscriptionShortName + '-vnt-01'
    $SubnetName = $LocationShortName + '-' + $SubscriptionShortName + '-sub-vnt01-' + $SubnetShortName
    $Vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName  $RgNameNetwork
    $Vnet
    $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    $ServerNicName = $VmName + '-' + $SubnetName.Split('-')[4] + '-01'

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
    $AvailabilitySetNameRequired = $true
    $AvailabilitySetName = $LocationShortName + '-' + $SubscriptionShortName + '-avs-' + $AppId + '-01'

    # Tags
    $Allocation = 'Shared'
    $AllocationGroup = 'GIS'
    $Project = 'S' + $SubscriptionShortName
    $ServiceLevel = 'SAND'
    $Wbs = 'I100.33040.02.56'

    # Data Disk(s) - disk number and disk size in GB (do not exceed 1023 GB per disk)
    $DataDisksRequired = $false 
    $StorageType = 'StandardLRS'
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
                                                      -Location $LocationName `
                                                      -Sku Aligned `
                                                      -PlatformFaultDomainCount 2 `
                                                      -PlatformUpdateDomainCount 5
        # Create tags
        $Tags = $null
        $Tags = @{allocation = $Allocation; allocation_group = $AllocationGroup; project = $Project; service_level = $ServiceLevel; wbs = $Wbs}

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
    # Retrieve public IP address 
    #
    ##################################################################################################################################################################################
    if ($PublicIpAddressRequired)
    { 
      $PublicIpAddress = New-AzureRmPublicIpAddress -AllocationMethod Static -ResourceGroupName $RgName -IpAddressVersion IPv4 -Location $LocationName `
                                                    -Name "$LocationShortName-$SubscriptionShortName-pub-$VmName-01"

      # Create tags
      $Tags = $null             
      $Tags = @{allocation = $Allocation; allocation_group = $AllocationGroup; project = $Project; service_level = $ServiceLevel; wbs = $Wbs}


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
                                                    -SubnetId $Subnet.Id  `
                                                    -PublicIpAddressId $PublicIpAddress.Id -Force -WarningAction SilentlyContinue
    Write-Verbose -Message ('SOL0001-Network Interface created: ' + ($NetworkInterface | Out-String))

    # Create tags
    $Tags = $null             
    $Tags = @{allocation = $Allocation; allocation_group = $AllocationGroup; project = $Project; service_level = $ServiceLevel; wbs = $Wbs}

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
    $Vm = Set-AzureRmVMOperatingSystem -VM $Vm -Linux -ComputerName $VmName -Credential $LocalAdminCredential -DisablePasswordAuthentication
    $Vm = Set-AzureRmVMSourceImage -VM $Vm -PublisherName $PublisherName -Offer $OfferName -Skus $SkuName -Version 'latest'

    # Configure SSH Key
    $KeyVaultSecret = Get-AzureKeyVaultSecret -VaultName weu-0005-key-keyvault-01 -Name LinuxPublicKey
    $Vm = Add-AzureRmVMSshPublicKey -VM $Vm -KeyData $KeyVaultSecret.SecretValueText -Path ('/home/' + $LocalAdminCredential.UserName + '/.ssh/authorized_keys')

    # Specify the NIC
    $Vm = Add-AzureRmVMNetworkInterface -VM $Vm -Id $NetworkInterface.Id -Primary

    # Specify the OS disk
    $Vm = Set-AzureRmVMOSDisk -VM $Vm -Name $OsDiskName -StorageAccountType StandardLRS -CreateOption FromImage -Caching ReadWrite

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
    $Tags = @{allocation = $Allocation; allocation_group = $AllocationGroup; project = $Project; service_level = $ServiceLevel; wbs = $Wbs}

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
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUTDkvcWrD9E81H0muTJWE9XWl
# JhGgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU6BoEYwPckjTe
# UVfbRB1OM6JdRrAwDQYJKoZIhvcNAQEBBQAEggEAdxk4sKO75bFhRzTX75LoCVHl
# qumLcLnSebgrTIArXzqkGN8J2FDWFSCp8zSCs+fr9AsWxjOcVjFHinhXF3qKnukl
# KOkd5jpYcb5UP0TdjkJf5MsRDMwVwczabMRIsld8bdz7wnOCATaDETsP9ZjLAj5Y
# ZayxtrDFxnBopl14RmXmfqxMovIL3r1JjXh2bNS03U05mIpp52mwpz6V15R46C7E
# M0WUS43lc7sw+mxmjLqvWz7K+lNETzW6yqyT4APN6tVwEyWxPLAt9VQUwxDP+HPZ
# 1ZlPZqzhPryQXcYMcBVrG0e4v3R3uYRLb3D/t6KYZRBzdJzdDvOeLRl78OSEFA==
# SIG # End signature block
