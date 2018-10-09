###############################################################################################################################################################
# Setting the Azure context including the storage context for the core storage account. The context setting is attempted in an endless loop of suspend/resume 
# of this runbook.
#
# Error Handling: There is no error handling avaialble in this pattern. Errors only occur if there is a problem with the infrastructure.
#                 These types of errors are automatically logged as errors in the runbooks log. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       TEC0005-AzureContextSet
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0005-AzureContextSet
{
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Storage, Azure.Storage, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  

  # Function to set context
  Function SetContext
  {
    try
    {
      $SubscriptionName = Get-AutomationVariable -Name 'VAR-AUTO-SubscriptionName'
      $StorageAccountName = Get-AutomationVariable -Name 'VAR-AUTO-StorageAccountName'
      $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
      $Result = Disconnect-AzureRmAccount -ErrorAction SilentlyContinue
      $AzureAccount = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $SubscriptionName -Force
      $StorageAccount = Get-AzureRmStorageAccount | Where-Object -FilterScript {$_.StorageAccountName -eq "$StorageAccountName"}
      $StorageContext = Set-AzureRmCurrentStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccount.ResourceGroupName
      Return 'Success'
    }
    catch
    {
      Return 'Failure'
    }
  }

  # Perform context setting, if not successful suspend workflow and re-try after workflow is resumed
  $Counter = $null
  do
  {
    $Counter++
    Write-Verbose -Message ('TEC0005-ContextSettingAttemptNumber: ' + ($Counter))

    $VerbosePreference = 'SilentlyContinue'    
    $ReturnCode = SetContext
    $VerbosePreference = 'Continue'
    if ($ReturnCode -eq 'Failure')
    {
      Write-Error -Message ('TEC0005-SetAzureContextFailed: See error log for details')
      Suspend-Workflow
    }
    else
    {
      $AzureRmContext = Get-AzureRmContext
      Write-Verbose -Message ('TEC0005-SetAzureContext: ' + ($AzureRmContext | Out-String))
    }
  }
  until ($ReturnCode -eq 'Success')
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDmjRKV8Deptw1Uv5CXxZydqa
# HPOgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZTdsiVw66Eow
# OZ66y3WeJRXxKcQwDQYJKoZIhvcNAQEBBQAEggEAnRlE93DvHKM77ST2Tv4rK8y8
# bF+bZCeZwButPzA80eahT1T9BiMw5ePLLJi07xv6rrqzQfZR0RzYCvVT5ByYNL0t
# 7UwXjwITqJ5RMPDwPyPnil8r9XsHJCH3ePN2CLZXLXqNP9ZwjoGWFlw0LD+pcU3C
# I22f52YHv36lVI5cJoOWdVqogWy9V/OSIcj5pBFXepfFb4ssXG3McS7bEZSGqw7J
# r435gGWDQ2coCOo37LMX7sZoAkhzI3861DUaDWbceaG2BM/8LT5g12wHnwn+4jXf
# j+0+whKkAimG5ySGmTDUXO3RWv/RDE+UF3g17C8VOmg1NWS9HuIN32R30uOhUA==
# SIG # End signature block
