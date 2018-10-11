###############################################################################################################################################################
# Creates a new server based on the input parameters.
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   File share to store CSV output, needs to run on Hybrid Runbook Worker (using New-PSDrive)
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow TEC0001-OmsLogExportToCsv
{
  [OutputType([object])] 	

  param
  (

  )

  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
 
  InlineScript
  {
    ###############################################################################################################################################################
    #
    # Create attributes
    #
    ###############################################################################################################################################################
    $ResourceGroupName = 'weu-0005-rsg-refomsdba-01'
    $WorkspaceName = 'rocweu0005refdba01'


    ###############################################################################################################################################################
    #
    # Export OMS Data of last hour to CSV
    #
    ###############################################################################################################################################################
    $Response =  Invoke-LogAnalyticsQuery -WorkspaceName $WorkspaceName -ResourceGroup $ResourceGroupName -SubscriptionId 245f98ee-7b91-415b-8edf-fd572af56252  `
                                          -Query 'search * | where TimeGenerated >= ago(1h) and TimeGenerated <= now()'
    
    $User = 'rocweu0005logs01s'
    $Password = ConvertTo-SecureString 'QzoG2vhBmChtQltyIBFZVY7EhXxLevnLKSo88CyuEGDhlsKCwT/N+gJ4xy4byKFzexRnwDOK+z/652I9S4JnFA==' -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($User, $Password)
    $Result = New-PSDrive -Name dest -Root \\rocweu0005logs01s.file.core.windows.net\logexport -Credential $Credential -PSProvider FileSystem

    $Result = Remove-Item dest:\LogExport.csv
    $Response.Results | export-csv dest:\LogExport.csv -noType -Force
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIUd3oFqwRjGwrLEGum1AP9Zg
# rS2gggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUgmJYPO0t9rdS
# jk+wH5zxVGegfIowDQYJKoZIhvcNAQEBBQAEggEAfkFRbF3jgkSJ9QpI46J4rURU
# TEjnAZF5aWazfF/xRPXx/DInwq6+s2NeszgSAqZBS1LPTxR33O5KQ+n3k+NIi72P
# Y2qIPaC+1jF0Vkh0JDRbs45GkI6OIA2nc+gUND+lautHL2qbL78Y9GlRH8loCLtd
# G+0Oc3codnodC8bxwUbU0da4IuEAdxsk4xrjecoBF8unqL6qxGQZXgXXe+fBxtoC
# dDWd/MiruGZh9MC3QJeio1a4ShYdKX1eYSmH44zybzR1VaZ2U+zpId6YGXVSxHAx
# A2VRI2OTDtG1amDd4bex/pi0fHgfxRmvDp3SHVehkDb8+VmMSfisOioAF3C3hA==
# SIG # End signature block
