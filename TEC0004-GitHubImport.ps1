###############################################################################################################################################################
# Imports the Runbooks from GitHub into Azure Automation. Prior to the import all Runbooks in the Azure Automation Account are deleted - except the 
# ones with Webhooks.
# This Runbook needs to be executed from the Automation Account to which the Runbooks are imported. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below 
#
# Template:       TEC0004-GitHubImport -GitHubRepo $GitHubRepo
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0004-GitHubImport
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $GitHubRepo = '/fbodmer/weu-0005-aut-dev-01'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Automation
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $GitHubRepo = $Using:GitHubRepo


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $RgName = Get-AutomationVariable -Name 'VAR-AUTO-CoreResourceGroup' -Verbose:$false
    $AutomationAccountName = Get-AutomationVariable -Name 'VAR-AUTO-AutomationAccountName' -Verbose:$false
    $GitHubCredentials = Get-AutomationPSCredential -Name 'CRE-AUTO-GitHubUser' -Verbose:$false

    # Convert to plain text and then to Base64, e.g. for use with non-Windows systems
    $Username = $GitHubCredentials.GetNetworkCredential().username
    $Password = $GitHubCredentials.GetNetworkCredential().password
    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo)} 

    Write-Verbose -Message ('TEC0004-CoreResourceGroup: ' + ($RgName))
    Write-Verbose -Message ('TEC0004-AutomationAccountName: ' + ($AutomationAccountName))


    ###########################################################################################################################################################
    #
    # Get list of all Runbooks
    #
    ###########################################################################################################################################################
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Result = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents" -Headers $Headers -UseBasicParsing -Verbose:$false
    $Runbooks = (($Result.Content | ConvertFrom-Json) | Where-Object {$_.name -Like '*.ps1'}).name
    Write-Verbose -Message ('TEC0004-RunbooksInGitHub: ' + ($Runbooks | Out-String))


    ###########################################################################################################################################################
    #
    # Delete existing Runbooks in Azure Automation Account - except the ones with a Webhook (preserve them)
    #
    ###########################################################################################################################################################
    # Prepare access to Azure Automation Runbooks
    $AutomationAccount = (Get-AzureRmAutomationAccount -ResourceGroupName $RgName | Where-Object {$_.AutomationAccountName -eq $AutomationAccountName})
    Write-Verbose -Message ('TEC0004-AutomatonAccountUsed: ' + $RgName + ' - ' + ($AutomationAccount | Out-String))

    # Get all Runbooks
    $RunbooksAll = @()
    $RunbooksAll = (Get-AzureRmAutomationRunbook -ResourceGroupName $RgName -AutomationAccountName $AutomationAccount.AutomationAccountName).Name
    Write-Verbose -Message ('TEC0004-AllRunbooksInAccount: ' + ($RunbooksAll | Out-String))

    # Get all Webhooks
    $Webhooks = @()
    $Webhooks = (Get-AzureRmAutomationWebhook -ResourceGroupName $RgName -AutomationAccountName $AutomationAccountName).RunbookName
    Write-Verbose -Message ('TEC0004-RunbooksWithWebhooks: ' + ($Webhooks | Out-String))

    # Runbooks that don't have Webhook configured
    $RunbooksWithoutWebhooks = $RunbooksAll | ?{$Webhooks -notcontains $_}
    Write-Verbose -Message ('TEC0004-RunbooksWithoutWebhooks: ' + ($RunbooksWithoutWebhooks | Out-String))
 
    # Remove all runbooks without Webhooks in Azure Automation Runbook Account
    $Counter = $RunbooksWithoutWebhooks.Count
    Write-Verbose -Message ('TEC0004-NumberOfRunbooksWithoutWebhooks: ' + $Counter)

    if($Counter -gt 0)
    {
      foreach ($RunbooksWithoutWebhook in $RunbooksWithoutWebhooks)
      { 
        $Result = Remove-AzureRmAutomationRunbook -ResourceGroupName $RgName `
                                                  -AutomationAccountName $AutomationAccountName `
                                                  -Name $RunbooksWithoutWebhook `
                                                  -Force
        Write-Verbose -Message ('TEC0004-RunbookDeleted: ' + $RunbooksWithoutWebhook)
      }
    }
    else
    {
      Write-Verbose -Message ('TEC0004-NoPatternRunbooksToDelete: There are no runbooks in the Automation Account to be deleted')
    }


    ###########################################################################################################################################################
    #
    # Import the Runbooks
    #
    ###########################################################################################################################################################
    foreach ($Runbook in $Runbooks)
    {
      # Get individual Runbooks in GitHub
      $RunbookGitHub = Invoke-WebRequest -Uri https://api.github.com/repos$GitHubRepo/contents/$Runbook -Headers $Headers -UseBasicParsing -Verbose:$false
      $RunbookContent = $RunbookGitHub.Content | ConvertFrom-Json
      $RunbookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($RunbookContent.content))
      $Result = Out-File -InputObject $RunbookContent -FilePath D:\$Runbook -Force

      # Import to Azure Automation
      $Result = Import-AzureRmAutomationRunbook -ResourceGroupName $RgName -AutomationAccountName $AutomationAccountName `
                                      -Type PowerShellWorkflow `
                                      -Path D:\$Runbook `
                                      -LogVerbose $true `
                                      -Published `
                                      -Description 'Imported from GitHub' `
                                      -Force
      Write-Verbose -Message ('TEC0004-RunbookImported: ' + $Runbook)
    }
  }
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUt390RsO0uY8aQm8WGG8lACxd
# jMagggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUPExUkiFb/afl
# i6Bjb/QdpeKwjr0wDQYJKoZIhvcNAQEBBQAEggEAqZjdXbbR+z3dn2652DkO4Pav
# 2h2xOM5mGn2D1DwOlcr1lnrnqwJ8NiBTK7ztGwhCmhTkYp1xL0rEiA8WCA+UBBQM
# nELS4K+vOWxK1Q4a/ZslPsZKtqnYYgvEfGh5wQFmNrSZkoaj6Tj4KDh0TQOqcK8g
# jbCIuAR9ocQ/uEpt5KRU3IbtcpFssCw1NdErk44577ByD6lxgAdgaJhzMbnyE1zt
# ktsP73KLMe4tKu8hkqoR2dbDSdKzv2zKbpceoze0zomtu0dogoSxPxhR0EsjKnza
# o3ko3l0Yuf3rpHkjNXieQ3Nre5WhYw3SEZfv5draeV/5mkE+X0dGR9RnYXX58w==
# SIG # End signature block
