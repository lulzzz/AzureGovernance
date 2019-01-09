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
    $Result = Import-Module AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $MailCredentials = Get-AutomationPSCredential -Name CRE-AUTO-MailUser -Verbose:$false                                                                          # Needs to use app password due to two-factor authentication


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
  $Contact = $Attributes.Attribute03

  Write-Verbose -Message ('SOL0055-Vnet1Name: ' + $Vnet1Name)
  Write-Verbose -Message ('SOL0055-Vnet2Name: ' + $Vnet2Name)
  Write-Verbose -Message ('SOL0055-Contact: ' + $Contact)


  ###########################################################################################################################################################
  #
  # Create VNET Peering
  #
  ###########################################################################################################################################################
  PAT0053-NetworkVnetPeeringNew -Vnet1Name $Vnet1Name -Vnet2Name $Vnet2Name


  #############################################################################################################################################################
  #
  # Send Mail confirmation
  #
  #############################################################################################################################################################
  $RequestBody = $RequestBody -Replace('","', "`r`n  ")
  $RequestBody = $RequestBody -Replace('@', '')
  $RequestBody = $RequestBody -Replace('{"', '')
  $RequestBody = $RequestBody -Replace('"}', '')
  $RequestBody = $RequestBody -Replace('":"', ' = ')
  $RequestBody = $RequestBody -Replace('  Attribute', 'Attribtue')
 
  try
  {
    Send-MailMessage -To $Contact -From felix.bodmer@outlook.com -Subject "Peering between $Vnet1Name and $Vnet1Name has been provisioned" `
                                  -Body $RequestBody -SmtpServer smtp.office365.com  -Credential $MailCredentials -UseSsl -Port 587
    Write-Verbose -Message ('SOL0007-ConfirmationMailSent')
  }
  catch
  {
    Write-Error -Message ('SOL0007-ConfirmationMailNotSent')
  }    
}