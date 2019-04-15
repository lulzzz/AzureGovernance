###############################################################################################################################################################
# Updates the ServiceNow Service Request Item (RTIM). This will set the status of the RTIM to 'Closed Complete' and send the server information to the user.
# 
# Output:         'Success' or 'Failure'
#
# Requirements:   AzureAutomationAuthoringToolkit
#
# Template:       PAT2901-SnowRitmUpdate -ServerNameLocalAdministrators $ServerNameLocalAdministrators -DomainZone $DomainZone -Memory $Memory `
#                                        -PrivateIpAddress $PrivateIpAddress -ServerName $ServerName -RITM $RITM `
#                                        -ApplicationDnsAliasFqdn $ApplicationDnsAliasFqdn -Cpu $Cpu -Uri $Uri
#
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow PAT2901-SnowRitmUpdate
{
  [OutputType([string])]
  
  param
  (
    [Parameter(Mandatory = $false)][string] $ServerNameLocalAdministrators = 'azw1234-LocalAdministrators',
    [Parameter(Mandatory = $false)][string] $DomainZone = 'customer.com',
    [Parameter(Mandatory = $false)][string] $Memory = '4',
    [Parameter(Mandatory = $false)][string] $PrivateIpAddress = '10.10.10.10',
    [Parameter(Mandatory = $false)][string] $ServerName = 'azw1234',
    [Parameter(Mandatory = $false)][string] $RITM = '9beb5cac4f7792005633bc511310c7ff',
    [Parameter(Mandatory = $false)][string] $ApplicationDnsAliasFqdn = 'appalias.customer.com',
    [Parameter(Mandatory = $false)][string] $Cpu = '2',
    [Parameter(Mandatory = $false)][string] $Uri = 'customerdev.service-now.com'
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  $VerbosePreference = 'Continue'
  TEC0005-AzureContextSet

  Write-Verbose -Message ('PAT2901-ServerNameLocalAdministrators: ' + $ServerNameLocalAdministrators)
  Write-Verbose -Message ('PAT2901-DomainZone: ' + $DomainZone)
  Write-Verbose -Message ('PAT2901-Memory: ' + $Memory)
  Write-Verbose -Message ('PAT2901-PrivateIpAddress: ' + $PrivateIpAddress)
  Write-Verbose -Message ('PAT2901-ServerName: ' + $ServerName)
  Write-Verbose -Message ('PAT2901-RITM: ' + $RITM)
  Write-Verbose -Message ('PAT2901-ApplicationDnsAliasFqdn: ' + $ApplicationDnsAliasFqdn)
  Write-Verbose -Message ('PAT2901-Cpu: ' + $Cpu)
  Write-Verbose -Message ('PAT2901-Uri: ' + $Uri)

  InlineScript 
  {
    $ServerNameLocalAdministrators = $Using:ServerNameLocalAdministrators
    $DomainZone = $Using:DomainZone 
    $Memory = $Using:Memory 
    $PrivateIpAddress = $Using:PrivateIpAddress
    $ServerName = $Using:ServerName
    $RITM = $Using:RITM
    $ApplicationDnsAliasFqdn = $Using:ApplicationDnsAliasFqdn
    $Cpu = $Using:Cpu
    $Uri = $Using:Uri
  
    # XML for SOAP call
    $Xml = [xml]@"
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:azur="http://www.service-now.com/AzureUpdateRITM">
       <soapenv:Header/>
       <soapenv:Body>
          <azur:execute>
             <!--Optional:-->
             <ServerNameLocalAdministrators>$ServerNameLocalAdministrators</ServerNameLocalAdministrators>
             <!--Optional:-->
             <DomainZone>$DomainZone</DomainZone>
             <!--Optional:-->
             <Memory>$Memory</Memory>
             <!--Optional:-->
             <PrivateIpAddress>$PrivateIpAddress</PrivateIpAddress>
             <!--Optional:-->
             <ServerName>$ServerName</ServerName>
             <!--Optional:-->
             <RITM>$RITM</RITM>
             <!--Optional:-->
             <ApplicationDnsAliasFqdn>$ApplicationDnsAliasFqdn</ApplicationDnsAliasFqdn>
             <!--Optional:-->
             <Cpu>$Cpu</Cpu>
             <!--Optional:-->
             <LocalAdminUsersRequested>LAUR</LocalAdminUsersRequested>
          </azur:execute>
       </soapenv:Body>
    </soapenv:Envelope>
"@

    # SOAP call to SNOW
    $Credentials = Get-AutomationPSCredential -Name CRE-AUTO-SnowTecUser
    $Uri = 'https://' + $Uri + '/AzureUpdateRITM.do?SOAP'
    $Return = Invoke-WebRequest -Uri $Uri -Method post -ContentType 'text/xml' -Body $Xml -Headers $Headers -Credential $Credentials
    
    Write-Verbose -Message ('PAT2901-SnowReturnMessage: ' + $Return.RawContent)

    If ($Return.RawContent.Contains('<message>RITM has been updated.</message>'))
    {
      Write-Verbose -Message ('PAT2901-SnowRitmUpdated: SNOW RITM with sys_id ' + $RITM + ' set to closed')
      Return 'Success'
    }
    else
    {
      Write-Verbose -Message ('PAT2901-SnowRitmNotUpdated: SNOW RITM with sys_id ' + $RITM + ' could not be updated')                    # No error handling implemented
      Return 'Failure'
    }
  }
}
