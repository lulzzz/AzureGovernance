###############################################################################################################################################################
# Creates a Peering between two VNETs. 
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0055-NetworkVnetPeeringNew
{
  [OutputType([object])] 	

  param
  (
    [object]$WebhookData 
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #
  # Assign/map data received by REST call from SNOW, to PowerShell variables
  #
  #############################################################################################################################################################
  $WebhookName = $WebhookData.WebhookName
  $RequestHeader = $WebhookData.RequestHeader
  $RequestBody = $WebhookData.RequestBody
  Write-Verbose -Message ('SOL0055-WebhookName: ' + $WebhookName)
  Write-Verbose -Message ('SOL0055-RequestHeader: ' + $RequestHeader)
  Write-Verbose -Message ('SOL0055-RequestBody: ' + $RequestBody)
  Write-Verbose -Message ('SOL0055-WebhookData: ' + $WebhookData)

  $Attributes = ConvertFrom-Json -InputObject $RequestBody
  Write-Verbose -Message ('SOL0055-Attributes: ' + $Attributes)

  $Vnet1Name = $Attributes.Attribute01
  $Vnet2Name = $Attributes.Attribute02
  $Gateway = $Attributes.Attribute03
  $Contact = $Attributes.Attribute04

  Write-Verbose -Message ('SOL0055-Vnet1Name: ' + $Vnet1Name)
  Write-Verbose -Message ('SOL0055-Vnet2Name: ' + $Vnet2Name)
  Write-Verbose -Message ('SOL0055-Contact: ' + $Gateway)
  Write-Verbose -Message ('SOL0055-Contact: ' + $Contact)


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $MailCredentials = Get-AutomationPSCredential -Name CRE-AUTO-MailUser -Verbose:$false                                                                          # Needs to use app password due to two-factor authentication
  $PortalUrl = Get-AutomationVariable -Name VAR-AUTO-PortalUrl -Verbose:$false


  #############################################################################################################################################################
  #  
  # Ensure request is received from portal
  #
  #############################################################################################################################################################
  if ($WebhookData.RequestHeader -match $PortalUrl)
  {
    Write-Verbose -Message ('SOL0011-Header: Header has required information')
  }
  else
  {
    Write-Error -Message ('SOL0011-Header: Header does not contain required information')
    return
  }


  ###########################################################################################################################################################
  #
  # Create VNET Peering
  #
  ###########################################################################################################################################################
  PAT0053-NetworkVnetPeeringNew -Vnet1Name $Vnet1Name -Vnet2Name $Vnet2Name -Gateway $Gateway


  #############################################################################################################################################################
  #
  # Send Mail confirmation
  #
  #############################################################################################################################################################
  $Body = "
            Vnet1: $Vnet1Name
            Vnet2: $Vnet2Name
            On-premise Gateway: $Gateway
            Contact: $Contact
          "
  try
  {
    Send-MailMessage -To $Contact -From $MailCredentials.UserName -Subject "Peering between $Vnet1Name and $Vnet1Name has been provisioned" `
                                  -Body $Body -SmtpServer smtp.office365.com  -Credential $MailCredentials -UseSsl -Port 587
    Write-Verbose -Message ('SOL0007-ConfirmationMailSent')
  }
  catch
  {
    Write-Error -Message ('SOL0007-ConfirmationMailNotSent')
  }    
}
