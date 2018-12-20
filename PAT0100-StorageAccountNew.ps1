###############################################################################################################################################################
# Creates a Storage Account (e.g. swiweu0010diag01s) in an existing Resource Group. Tags the Storage Accounts.
# Configures Firewall - allow access from all Subnets in all VNETs as well as Azure Services.
#
# Output:         $StorageAccountName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0100-StorageAccountNew -StorageAccountNameIndividual $StorageAccountNameIndividual -ResourceGroupName $ResourceGroupName `#                                           -StorageAccountType $StorageAccountType#                                           -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                           -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact -Automation $Automation
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0100-StorageAccountNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $StorageAccountNameIndividual = 'diag',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-0010-rsg-core-01',
    [Parameter(Mandatory=$false)][String] $StorageAccountType = 'standard',                                                                                      # 'standard' / 'premium'
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


  $StorageAccountName = InlineScript
  {
    $StorageAccountNameIndividual = $Using:StorageAccountNameIndividual
    $ResourceGroupName = $Using:ResourceGroupName
    $StorageAccountType = $Using:StorageAccountType
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

    Write-Verbose -Message ('PAT0100-StorageAccountNameIndividual: ' + ($StorageAccountNameIndividual))
    Write-Verbose -Message ('PAT0100-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0100-StorageAccountType: ' + ($StorageAccountType))
    Write-Verbose -Message ('PAT0100-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0100-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0100-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0100-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0100-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0100-Budget: ' + ($Budget))
    Write-Verbose -Message ('PAT0100-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0100-Automation: ' + ($Automation))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0100-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Storage Account name
    #
    ###########################################################################################################################################################
    $StorageAccountName = 'swi' + $RegionCode + $SubscriptionCode + $StorageAccountNameIndividual                                                                # e.g. swiweu0010diag01s
  
    
    $StorageAccountExisting = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -like "$StorageAccountName*"} `
                                                        | Sort-Object Name -Descending | Select-Object -First $True
    if ($StorageAccountExisting.Count -gt 0)                                                                                                                     # Skip if first Storage Account with this name
    {
      Write-Verbose -Message ('PAT0100-StorageAccountHighestCounter: ' + ($StorageAccountExisting.StorageAccountName))

      $Counter = 1 + ($StorageAccountExisting.StorageAccountName.SubString(($StorageAccountExisting.StorageAccountName).Length-3,2))                             # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $StorageAccountName = $StorageAccountName + $Counter1 + $StorageAccountType.Substring(0,1)                                                                 # Compile name    
    }
    else
    {
      $StorageAccountName = $StorageAccountName + '01' + $StorageAccountType.Substring(0,1)                                                                      # Compile name for first Key Vault with this name
    }
    Write-Verbose -Message ('PAT0100-StorageAccountName: ' + ($StorageAccountName)) 


    ###########################################################################################################################################################
    #
    # Check if Storage Account exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Error -Message ('PAT0100-StorageAccountExisting: ' + ($StorageAccountName))
      Return
    }
  
    try
    {
      $Result = (New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $RegionName -Kind StorageV2 `
                                                     -SkuName ($StorageAccountType + '_LRS')).Id
      Write-Verbose -Message ('PAT0100-StorageAccountCreated: ' + ($StorageAccountName))
    }
    catch
    {
      Write-Error -Message ('PAT0100-StorageAccountNotCreated: ' + $Error[0]) 
      Return
    }


    ###########################################################################################################################################################
    #
    # Configure Firewall - allow access from all Subnets in all VNETs as well as Azure Services
    #
    ###########################################################################################################################################################
    # Deny access by default but allow Azure Services to bypass the Firewall
    $Result = Update-AzureRMStorageAccountNetworkRuleSet -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -DefaultAction Deny `
                                                         -Bypass AzureServices
    Write-Verbose -Message ('PAT0100-FirewallConfigured: ' + ($Result | Out-String))

    # Allow access by all Subnets in all VNETs in the Subscription
    $Vnets = Get-AzureRmVirtualNetwork
    foreach ($Vnet in $Vnets)
    {
      foreach ($Subnet in $Vnet.Subnets)
      {
        $Result = Add-AzureRMStorageAccountNetworkRule -AccountName $StorageAccountName -ResourceGroupName $ResourceGroupName `
                                                       -VirtualNetworkResourceId $Subnet.Id
      }
      Write-Verbose -Message ('PAT0100-FirewallConfiguredForVnet: ' + ($Result | Out-String))
    }

  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0100-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmResource -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ResourceType '/Microsoft.Storage/storageAccounts' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0100-StorageAccountTagged: ' + ($StorageAccountName))


    ###########################################################################################################################################################
    #
    # Return Storage Account ID
    #
    ###########################################################################################################################################################
    Return $StorageAccountName
  }
  Return $StorageAccountName
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXed1WSbc8jqcGXvVWBcUDvev
# yC2gggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUFovnpFwdL6U+
# hjrXRFCWV3R89xAwDQYJKoZIhvcNAQEBBQAEggEAP7cmTBTZcmrZ+j+C4Nf61/1M
# 5Ehes/8AbcSYLTYkVEKD0/YQPawHJr0WrmDG4lKlTXjIGtH2ddH6ngdAbXXDyZUb
# yHOL3t4HxoqI/9xo4AhJd6k0UzV/CFNDVsYMpnq69w5CH4PwqR2tlxsjcqGqxRD3
# ACucKj9XHEaQGEkoht2Cqq2RZrWRPh4A3DCNvGowefYCohJBmAhGLdVFE5DMZyiG
# xyHUH05CqbgitVGquCFxIrfT2vb3j+0kn4wPEKKelyM8AU8kwiSNZh8TFLJGu9mr
# mWBpeKQtv62QtBiS/1i2xRS/P9dFW3RuldPNiV2GXT4+YJBg2KVSrxDweMNkgQ==
# SIG # End signature block
