###############################################################################################################################################################
# Creates a Key Vault (e.g. weu-0010-key-keyvault-01) in an existing Resource Group. Tags the Key Vault. 
# Adds Key Vault to the corresponding Log Analytics Workspace (e.g. swiweu0010security01).
# 
# Output:         $KeyVaultName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual $KeyVaultNameIndividual -ResourceGroupName $ResourceGroupName `#                                             -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                             -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact -Automation $Automation
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0250-SecurityKeyVaultNew
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $KeyVaultNameIndividual = 'keyvault',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-0010-rsg-security-01',
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
    $Result = Import-Module AzureRM.Insights, AzureRM.KeyVault, AzureRM.OperationalInsights, AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $KeyVaultName = InlineScript
  {
    $KeyVaultNameIndividual = $Using:KeyVaultNameIndividual
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
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
    
    # Log Analytic Workspace
    $LogAnalyticsWorkspaceName = ('swi' + $RegionCode + $SubscriptionCode + 'security01')                                                                        # e.g. swiweu0010security01
    $ResourceGroupNameSecurity = ($RegionCode + "-$SubscriptionCode-rsg-security-01")                                                                            # e.g. weu-0010-rsg-security-01

    Write-Verbose -Message ('PAT0250-KeyVaultNameIndividual: ' + ($KeyVaultNameIndividual))
    Write-Verbose -Message ('PAT0250-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0250-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0250-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0250-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0250-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0250-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0250-Budget: ' + ($Budget))
    Write-Verbose -Message ('PAT0250-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0250-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0250-LogAnalyticsWorkspaceName: ' + ($LogAnalyticsWorkspaceName))
    Write-Verbose -Message ('PAT0250-ResourceGroupNameSecurity: ' + ($ResourceGroupNameSecurity))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0250-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Key Vault name
    #
    ###########################################################################################################################################################
    $KeyVaultName = $RegionCode + '-' + $SubscriptionCode + '-' + 'key' + '-' + $KeyVaultNameIndividual                                                          # e.g. weu-0010-key-keyvault-01
    $KeyVaultExisting = Get-AzureRmKeyVault | Where-Object {$_.VaultName -like "$KeyVaultName*"} `
                                            | Sort-Object Name -Descending | Select-Object -First $True
    if ($KeyVaultExisting.Count -gt 0)                                                                                                                           # Skip if first Key Vault with this name
    {
      Write-Verbose -Message ('PAT0250-KeyVaultHighestCounter: ' + ($KeyVaultExisting.VaultName))

      $Counter = 1 + ($KeyVaultExisting.VaultName.SubString(($KeyVaultExisting.VaultName).Length-2,2))                                                           # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $KeyVaultName = $KeyVaultName + '-' + $Counter1                                                                                                            # Compile name    
    }
    else
    {
      $KeyVaultName = $KeyVaultName + '-' + '01'                                                                                                                 # Compile name for first Key Vault with this name
    }
    Write-Verbose -Message ('PAT0250-KeyVaultName: ' + ($KeyVaultName))


    ###########################################################################################################################################################
    #
    # Check if Key Vault exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Verbose -Message ('PAT0250-KeyVaultExisting: ' + ($KeyVaultName))
      Return
    }
  
    try
    {
      $KeyVault = New-AzureRmKeyVault -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -Location $RegionName
      Write-Verbose -Message ('PAT0250-KeyVaultCreated: ' + ($KeyVaultName))
    }
    catch
    {
      Write-Error -Message ('PAT0250-KeyVaultNotCreated: ' + ($Error[0]))
      Return
    }

    ###########################################################################################################################################################
    #
    # Add Key Vault to Log Analytics Workspace e.g. swiweu0010security01
    #
    ###########################################################################################################################################################
    $LogAnalyticsWorkspace = Get-AzureRmOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupNameSecurity 
    $Result = Set-AzureRmDiagnosticSetting -ResourceId $KeyVault.ResourceId  -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true
    Write-Verbose -Message ('PAT0250-KeyVaultAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))
      
  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0250-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmResource -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.KeyVault/vaults' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0250-KeyVaultTagged: ' + ($KeyVaultName))


    ###########################################################################################################################################################
    #
    # Return Resource Group name
    #
    ###########################################################################################################################################################
    Return $KeyVaultName
  }
  Return $KeyVaultName
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDa3+4GREoJ+yDFUWieN7nosq
# NTmgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUILJ09wJrE+h1
# MXu+LFHBTl4ljuQwDQYJKoZIhvcNAQEBBQAEggEAEr/rV++iVsHAfDqyI4pX6Akd
# V8Wq527Dv1R758XW9gVZC1EPLLi75RAse3pIwCU45bBbd179c10aZslENPglNFrg
# ucd4LuLW4xeSX5UGPjBjmfSNK3nssd5Zfrq8Fa9HPNH2ot8eD+itglhnb3NcHLam
# AHuzALHxgOBF3zF36no7n1r3yIZX0x6X0DXfcThboOdC0e2d6/PBN/XEN+I+DGFE
# RBD0n4j7YNFoSzZWSWaRPOlakm1sqmHvmq59YhXFBWJmytZmNW8T6tMNgt4Hnv0u
# QvEYEf0styrcyG9M93ZBUQCF6afhav6FdtmK0+WBUcOuj9eKUQqCHgz6y46gDA==
# SIG # End signature block
