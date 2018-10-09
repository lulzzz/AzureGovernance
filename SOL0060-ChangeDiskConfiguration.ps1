####################################################################################################################################################################################
# This is a dummy runbook to illustrate integration with OMS Alerting.
# 
# Error Handling:   None 
#
# Output:           None
#
# Requirements:     None
#
# Template:         Invoked by OMS
#
# Change log:
# 1.0           Initial version
#
####################################################################################################################################################################################
workflow SOL0060-ChangeDiskConfiguration
{
  param
  (
    [object]$WebhookData    
  )

  $VerbosePreference = 'Continue'

  ##################################################################################################################################################################################
  #
  # Login to Account and select Subscription, this context is passed to all runbooks that are called from this runbook.
  # The same assets will be used in all subscriptions, however the contents (user/password or variable content) configured in the individual subscriptions might differ. 
  # This allows for this runbook to be used unchanged in the different subscriptions.
  #
  ##################################################################################################################################################################################
  # TEC0005-SetAzureContext

  ##################################################################################################################################################################################
  #
  # Assign/map data received by REST call from SNOW, to PowerShell variables
  #
  ##################################################################################################################################################################################
  $WebhookName = $WebhookData.WebhookName
  $RequestHeader = $WebhookData.RequestHeader
  $RequestBody = $WebhookData.RequestBody
  Write-Verbose -Message ('SOL0060-WebhookName: ' + $WebhookName)
  Write-Verbose -Message ('SOL0060-RequestHeader: ' + $RequestHeader)
  Write-Verbose -Message ('SOL0060-RequestBody: ' + $RequestBody)
  Write-Verbose -Message ('SOL0060-WebhookData: ' + $WebhookData)

  $OmsAttributes = ConvertFrom-Json -InputObject $RequestBody
  Write-Verbose -Message ('SOL0060-OmsAttributes: ' + $OmsAttributes)

  $ServerName = $OmsAttributes.Computer
    
  Write-Verbose -Message ('SOL0060-ServerName (w0001): ' + $ServerName)
  Return
}
