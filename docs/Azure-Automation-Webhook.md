### Calling Runbook
```powershell
###################################################################################################################################################################################
# Simulates the ServiceNow REST call used to trigger the VM build in Azure Automation.
# 
# Error Handling: None
#
# Output:         None
#
# Requirements:   None
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###################################################################################################################################################################################
workflow PAT2902-SnowRestWindows
{
  param
  (
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue01 = 'DEPT-1',                           # $DepartmentName 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue02 = 'owner.name@customer.com',          # $ServerOwnerName 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue03 = 'Windows Server 2016'               # $RequiredOperatingSystem - 'Windows Server 2012 R2' / 'Windows Server 2016'
  )

  $JSONBody = @"
    {
        "SnowAttribute01":"$SnowAttributeValue01",
        "SnowAttribute02":"$SnowAttributeValue02",
        "SnowAttribute03":"$SnowAttributeValue03"
    }
"@

  TEC0005-AzureContextSet
  $WebHook = Get-AutomationVariable -Name 'VAR-AUTO-SOL0001WebHook'   

  # Invokes using the Hybrid Runbook Worker 
  Invoke-RestMethod -Uri $WebHook `
                    -Body $JSONBody `
                    -Method Post 

}
```

### Called Runbook

```powershell
###############################################################################################################################################################
# Creates Windows Server based on a SNOW service request. The Runbook is invoked by a REST call from SNOW using a Webhook.
# 
# Output:           Log entry that runbook has completed, this doesn't mean that error could have been logged
#
# Requirements:     See Import-Module in code below
#
# Template:
#    $JSONBody = @"
#    {
#        "SnowAttribute01":"$SnowAttributeValue01", 
#        "SnowAttribute..":"$SnowAttributeValue.."
#    }
#"@      
#    Invoke-RestMethod   -Uri "https://s2events.azure-automation.net/webhooks?token=<token>" `
#                        -Body $JSONBody `
#                        -Method Post
#
# Change log:
# 1.0           Initial version
#
###############################################################################################################################################################
workflow SOL0001-CreateWindowsServer
{
  param
  (
    [object]$WebhookData    
  )

  #############################################################################################################################################################
  #
  # Assign/map data received by REST call from SNOW, to PowerShell variables
  #
  #############################################################################################################################################################
  $WebhookName = $WebhookData.WebhookName
  $RequestHeader = $WebhookData.RequestHeader
  $RequestBody = $WebhookData.RequestBody
  Write-Verbose -Message ('SOL0001-WebhookName: ' + $WebhookName)
  Write-Verbose -Message ('SOL0001-RequestHeader: ' + $RequestHeader)
  Write-Verbose -Message ('SOL0001-RequestBody: ' + $RequestBody)
  Write-Verbose -Message ('SOL0001-WebhookData: ' + $WebhookData)

  $SnowAttributes = ConvertFrom-Json -InputObject $RequestBody
  Write-Verbose -Message ('SOL0001-SnowAttributes: ' + $SnowAttributes)

  $DepartmentName = $SnowAttributes.SnowAttribute01
  $ServerOwnerName = $SnowAttributes.SnowAttribute02
  $RequiredOperatingSystem = $SnowAttributes.SnowAttribute03
    
  Write-Verbose -Message ('SOL0001-DepartmentName (DEPT): ' + $DepartmentName)
  Write-Verbose -Message ('SOL0001-ServerOwnerName (user.name@customer.com): ' + $ServerOwnerName)
  Write-Verbose -Message ('SOL0001-RequiredOperatingSystem (Windows Server 2016): ' + $RequiredOperatingSystem)
}
```