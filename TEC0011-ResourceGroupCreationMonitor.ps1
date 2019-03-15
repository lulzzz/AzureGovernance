###############################################################################################################################################################
# An Event Grid Subscription monitors the creation of a Resource Group. 
# Once a Resource Group is created the Event Grid Subscription trigger this Runbook using a Webhook.
# The Channel configured on the Runbook's Webhook is then used by this Runbook to send a Message to a Teams channel.
# 
# Output:         None
#
# Requirements:   See Import-Module in code below / Event Grid Subscription / Teams channel with a Webhook connector
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow TEC0011-ResourceGroupCreationMonitor
{
  [OutputType([object])] 	

  param
  (
    [parameter (Mandatory=$false)] [object] $WebhookData,
    [parameter (Mandatory=$false)] $ChannelURL
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    #$VerbosePreference = 'SilentlyContinue'
    #$Result = Import-Module 
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #
  # Assign/map data received by REST call from SNOW, to PowerShell variables
  #
  #############################################################################################################################################################
  InlineScript
  {
    $WebhookData = $Using:WebhookData
    $ChannelURL = $Using:ChannelURL

    $WebhookName = $WebhookData.WebhookName
    $RequestHeader = $WebhookData.RequestHeader
    $RequestBody = $WebhookData.RequestBody
    Write-Verbose -Message ('TEC0011-WebhookName: ' + $WebhookName)
    Write-Verbose -Message ('TEC0011-RequestHeader: ' + $RequestHeader)
    Write-Verbose -Message ('TEC0011-RequestBody: ' + $RequestBody)
    Write-Verbose -Message ('TEC0011-WebhookData: ' + $WebhookData)
    Write-Verbose -Message ('TEC0011-ChannelURL: ' + $ChannelURL)

    $Attributes = ConvertFrom-Json -InputObject $RequestBody
    $OperationName = $Attributes.Data.OperationName
    $Status = $Attributes.Data.Status
    $ResourceUri = $Attributes.Data.resourceUri
    $Name = $Attributes.Data.Claims.Name  
  
    Write-Verbose -Message ('TEC0011-OperationName: ' + $OperationName)
    Write-Verbose -Message ('TEC0011-Status: ' + $Status)
    Write-Verbose -Message ('TEC0011-ResourceUri: ' + $ResourceUri)
    Write-Verbose -Message ('TEC0011-Name: ' + $Name)


    #############################################################################################################################################################
    #  
    # Write message to Teams
    #
    #############################################################################################################################################################
    if($OperationName -match 'Microsoft.Resources/subscriptions/resourceGroups/write' -and $Status -match "Succeeded")
    {
      $Body = @{
                 'Text'= 'OperationName: ' + $OperationName + ' / ' + 'Status: ' + $Status + ' / ' + 'ResourceUri: ' + $ResourceUri + ' / ' + 'Name: ' + $Name
               }
      $Body = $Body | ConvertTo-Json
      Write-Verbose -Message ('TEC0011-Body: ' + $Body | Out-String)
    
      Invoke-RestMethod -Method Post -Uri $ChannelURL -Body $Body -Header @{'accept'='application/json'}
    }
  }
}
