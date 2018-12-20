###############################################################################################################################################################
# Resets the test bed used for testing the Solutions
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       ResetTestBed -SubscriptionCode $SubscriptionCode
#                                                     
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow ResetTestBed
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'Development-de'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  
  ###########################################################################################################################################################
  #
  # Parameters
  #
  ###########################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false


  ###########################################################################################################################################################
  #
  # Change to Target Subscription
  #
  ###########################################################################################################################################################
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
  Write-Verbose -Message ('ResetTestBed-TargetSubscription: ' + ($Subscription | Out-String))
  $Result = Disconnect-AzureRmAccount
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('ResetTestBed-AzureContextChanged: ' + ($AzureContext | Out-String))


  ###########################################################################################################################################################
  #
  # Remove Resources created by SOL0001
  #
  ###########################################################################################################################################################
  $ResourceGroups = @()
  $ResourceGroups = 'neu-de-rsg-core-01','neu-de-rsg-network-01','neu-de-rsg-security-01', `
                    'weu-de-rsg-core-01','weu-de-rsg-network-01','weu-de-rsg-security-01'
  foreach -parallel ($ResourceGroup in $ResourceGroups)
  {
    Remove-AzureRmResourceGroup $ResourceGroup -Force
  }
  
  Remove-AzureRmPolicyAssignment -Id '/subscriptions/2ed9306c-a0ac-4231-bc8d-f74e3cb54bde/providers/Microsoft.Authorization/policyAssignments/Allowed locations'


  ###########################################################################################################################################################
  #
  # Reset Azure Table Ipam in the Core Storage Account
  #
  ###########################################################################################################################################################
  TEC0005-AzureContextSet
  InlineScript
  {
    # Update all entries
    $Table = Get-AzureStorageTable -Name Ipam
    $TableEntries = Get-AzureStorageTableRowAll -table $Table 
    foreach ($TableEntry in $TableEntries)
    {
      $TableEntry.VnetName = ''
      $TableEntry.SubnetName = ''
      $TableEntry | Update-AzureStorageTableRow -table $Table
    }
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtOv1jf9l0fJOs/SHpGG7Hc8r
# aLugggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKaCyDg3lcBJt
# 0sZa/qqc91bSs2QwDQYJKoZIhvcNAQEBBQAEggEAgLJJpo05WDdPurbZOop8r4D7
# Y7oHihgjn+vxhTh0xBmwVW/2lGyMuWrArYw3sQ8tQ8G03BVgm0/OdxRqoX+d0W1s
# skZDaew897Eth5XKVAYrysPkDs8HYq3T2S3Ro5bEXOzYqJqcxE7pp+TESgbg9ZBa
# BmTYK2VLHEl2x1zZHPBErgyROws6TyJ+1p/PF7wssbMr2biPXqSbFwZ6HKIIGyOr
# L27jc2A6dKISdQXzwzXmFW5P9/IN4i6x1IaOBsPIXSas7kWaPS+Y29WUdri+0hAK
# ws8gP9RAWQhwUcnU3dJXW3X5S7vKgIvQl0mAryW5H6+jm6dSXCroqXk6vj0k9Q==
# SIG # End signature block
