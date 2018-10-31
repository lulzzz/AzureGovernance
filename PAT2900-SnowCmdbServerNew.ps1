 ###############################################################################################################################################################
# Creating the required CIs in the ServiceNow CMDB. This includes cmdb_ci_win/linux_server and in the case of an Availability Set the corresponding cmdb_ci_cluster 
# and cmdb_ci_cluster_node. In addition, all CIs are connected to the cmdb_ci_environment using the relationship table cmdb_environment_to_ci.
#
# Error Handling: Errors related to the execution of the cmdlets are listed in the runbooks log.
#                 On the first failure the pattern will return control to the parent runbook
#
# Output:         'Success' or 'Failure'
# 
# Template:       PAT0013-UpdateCmdb -DepartmentName $DepartmentName -ServerName $ServerName -ServerOwnerName $ServerOwnerName -ServerTier $ServerTier `
#                                    -ApplicationName $ApplicationName -ApplicationDescription $ApplicationDescription -ServerEndOfLife $ServerEndOfLife `
#                                    -ReqRitm $ReqRitm -Uri $Uri -AvailabilitySetName $AvailabilitySetName -CountryName $CountryName `
#                                    -PrivateIpAddress $PrivateIpAddress
#
# Requirements:   - 
#
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow PAT2900-SnowCmdbServerNew
{
  [OutputType([string])]
  
  param
  (
    [Parameter(Mandatory = $false)][String] $DepartmentName = 'FIBS_TC',
    [Parameter(Mandatory = $false)][String] $ServerName = 'li-felixc02',
    [Parameter(Mandatory = $false)][String] $ServerOwnerName = 'Cuauhtemoc.Tello@hilti.com',
    [Parameter(Mandatory = $false)][String] $ServerTier = 'Crash and Burn',
    [Parameter(Mandatory = $false)][String] $ApplicationName = 'SCOM',
    [Parameter(Mandatory = $false)][String] $ApplicationDescription = 'SCOM Database',
    [Parameter(Mandatory = $false)][String] $ServerEndOfLife = '2019.12.31',
    [Parameter(Mandatory = $false)][String] $ReqRitm = 'REQ0098779 RITM0125931',
    [Parameter(Mandatory = $false)][String] $Uri = 'hiltidev.service-now.com',
    [Parameter(Mandatory = $false)][String] $AvailabilitySetName = '',
    [Parameter(Mandatory = $false)][String] $CountryName = 'Liechtenstein',
    [Parameter(Mandatory = $false)][String] $PrivateIpAddress = '10.208.0.138'
  )

  $VerbosePreference = 'Continue'

  TEC0005-SetAzureContext

  #############################################################################################################################################################
  #
  # Intialize parameters
  #
  #############################################################################################################################################################
  $CredentialsAutomationUser = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
  $CredentialsSnowUser = Get-AutomationPSCredential -Name 'CRE-AUTO-SnowTecUser'
  
  $ServerName = $ServerName.ToUpper()
  $AvailabilitySetName = $AvailabilitySetName.ToUpper()
  $ServerEndOfLife = $ServerEndOfLife.Replace('.', '-')
  $StartDate = Get-Date -UFormat '%Y-%m-%d'
  $AssignmentGroup = 'HILTI Infrastructure Platform Services'
  $Manufacturer = 'Microsoft Corporation'
  $ModelId = 'Virtual Machine'
  $DeploymentMethod = Get-AutomationVariable -Name 'VAR-AUTO-HaoVersion'
  $ResourceGroupName = (Get-AzureRmResource | Where-Object {$_.Name -eq $ServerName}).ResourceGroupName

  # Determine if Windows or Linux server
  if (((Get-AzureRmVm -Name $ServerName -ResourceGroup $ResourceGroupName).OSProfile.WindowsConfiguration).Count -ne 0)
  {
    $ServerCi = 'cmdb_ci_win_server'
    $SerialNumber = (New-CimSession -ComputerName $PrivateIpAddress -Credential $CredentialsAutomationUser | `
                     Get-CimInstance -ClassName Win32_ComputerSystemProduct -Namespace root\CIMV2).IdentifyingNumber
  }
  else
  {
    $ServerCi = 'cmdb_ci_linux_server'
  }

  Write-Verbose -Message ('PAT0013-DepartmentName: ' + $DepartmentName)
  Write-Verbose -Message ('PAT0013-ServerName: ' + $ServerName)
  Write-Verbose -Message ('PAT0013-ServerOwnerName: ' + $ServerOwnerName)
  Write-Verbose -Message ('PAT0013-ServerTier: ' + $ServerTier)
  Write-Verbose -Message ('PAT0013-ApplicationName: ' + $ApplicationName)
  Write-Verbose -Message ('PAT0013-ApplicationDescription: ' + $ApplicationDescription)
  Write-Verbose -Message ('PAT0013-ServerEndOfLife: ' + $ServerEndOfLife)
  Write-Verbose -Message ('PAT0013-ReqRitm: ' + $ReqRitm)
  Write-Verbose -Message ('PAT0013-SerialNumber: ' + $SerialNumber)
  Write-Verbose -Message ('PAT0013-Uri: ' + $Uri)
  Write-Verbose -Message ('PAT0013-AvailabilitySetName: ' + $AvailabilitySetName)
  # $CountryName should be written to cmdb_ci_win/linux_server as to Location attribute. This is currently not working because the Location attribute in 
  # SNOW is used for companies instead of locations. Once this is remediated in SNOW this should work.
  Write-Verbose -Message ('PAT0013-CountryName: ' + $CountryName)
  Write-Verbose -Message ('PAT0013-PrivateIpAddress: ' + $PrivateIpAddress)
  Write-Verbose -Message ('PAT0013-StartDate: ' + $StartDate)
  Write-Verbose -Message ('PAT0013-AssignmentGroup: ' + $AssignmentGroup)
  Write-Verbose -Message ('PAT0013-Manufacturer: ' + $Manufacturer)
  Write-Verbose -Message ('PAT0013-ModelId: ' + $ModelId)
  Write-Verbose -Message ('PAT0013-DeploymentMethod: ' + $DeploymentMethod)
  Write-Verbose -Message ('PAT0013-ServerCi: ' + $ServerCi)


  #############################################################################################################################################################
  #
  # Create cmdb_ci_win/linux_server
  #
  #############################################################################################################################################################
  $Body = [xml]@"
  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/$ServerCi">
      <soapenv:Header/>
      <soapenv:Body>
        <insert>
          <assignment_group>$AssignmentGroup</assignment_group>
          <host_name>$ServerName</host_name>
          <ip_address>$PrivateIpAddress</ip_address>
          <justification>$ApplicationName</justification>
          <location>$CountryName</location>
          <manufacturer>$Manufacturer</manufacturer>
          <model_id>$ModelId</model_id>
          <name>$ServerName</name>
          <comments>$DeploymentMethod</comments>
          <po_number>$ReqRitm</po_number>
          <serial_number>$SerialNumber</serial_number>
          <short_description>$ApplicationDescription</short_description>
          <start_date>$StartDate</start_date>
          <warranty_expiration>$ServerEndOfLife</warranty_expiration>
        </insert>
      </soapenv:Body>
  </soapenv:Envelope>
"@

  $WebServiceUri = 'https://' + $Uri + '/' + $ServerCi +'.do?SOAP' 
  $Result = $null
  $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
  $SnowSysIdWindowsServer = $Result.RawContent -split '<sys_id>'
  $SnowSysIdWindowsServer = $SnowSysIdWindowsServer[1] -split '</sys_id>'
  $SnowSysIdWindowsServer = $SnowSysIdWindowsServer[0]

  If ($SnowSysIdWindowsServer.Length -ne 0)
  {
    Write-Verbose -Message ('PAT0013-SnowWindowsServerCiCreated: ' + $ServerCi + ' sys_id ' + $SnowSysIdWindowsServer)
  }
  else
  {
    Write-Verbose -Message ('PAT0013-SnowWindowsServerCiCreationFailed: ' + $Result.RawContent)
    Return 'Failure'
  }
  
  # Create relationship CI -> Environment
  $Body = [xml]@"
  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
      <soapenv:Header/>
      <soapenv:Body>
        <insert>
          <ci>$SnowSysIdWindowsServer</ci>
          <environment>$ServerTier</environment>
        </insert>
      </soapenv:Body>
  </soapenv:Envelope>
"@
  $WebServiceUri = 'https://' + $Uri + '/cmdb_environment_to_ci.do?SOAP' 
  $Result = $null
  $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
  $SnowSysIdEnvCiRel = $Result.RawContent -split '<sys_id>'
  $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[1] -split '</sys_id>'
  $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[0]

  If ($SnowSysIdEnvCiRel.Length -ne 0)
  {
    Write-Verbose -Message ('PAT0013-SnowWindowsServerCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
  }
  else
  {
    Write-Verbose -Message ('PAT0013-SnowWindowsServerCiRelatedToEnvironmentFailed: ' + $Result.RawContent)
    Return 'Failure'
  }
 

  #############################################################################################################################################################
  #
  # Create cluster - This is for VMs deployed to Availability Sets - VMs in Availability Zones are not modeled as clusters
  #
  #############################################################################################################################################################
  If ($AvailabilitySetName.Length -gt 1)                                                                                                                         # Availability Zone is a single digit number
  {
    # Check if CI cmdb_ci_cluster is existing
    $Body = [xml]@"
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:inc="http://www.service-now.com/cmdb_ci_cluster">
       <soapenv:Header/>
       <soapenv:Body>
          <inc:getKeys>
            <name>$AvailabilitySetName</name>
          </inc:getKeys>
       </soapenv:Body>
    </soapenv:Envelope>
"@
    $WebServiceUri = 'https://' + $Uri + '/cmdb_ci_cluster.do?SOAP' 
    $Result = $null
    $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
    $SnowSysIdAvs = $Result.RawContent -split '<sys_id>'
    $SnowSysIdAvs = $SnowSysIdAvs[1] -split '</sys_id>'
    $SnowSysIdAvs = $SnowSysIdAvs[0]

    # Create CI cmdb_ci_cluster if not existing
    If ($SnowSysIdAvs.Length -eq 0)
    {
      $Body = [xml]@"
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_ci_cluster">
          <soapenv:Header/>
          <soapenv:Body>
            <insert>
              <name>$AvailabilitySetName</name>
            </insert>
          </soapenv:Body>
      </soapenv:Envelope>
"@
      $WebServiceUri = 'https://' + $Uri + '/cmdb_ci_cluster.do?SOAP' 
      $Result = $null
      $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
      $SnowSysIdAvs = $Result.RawContent -split '<sys_id>'
      $SnowSysIdAvs = $SnowSysIdAvs[1] -split '</sys_id>'
      $SnowSysIdAvs = $SnowSysIdAvs[0]

      If ($SnowSysIdAvs.Length -ne 0)
      {
        Write-Verbose -Message ('PAT0013-SnowClusterCiCreated: cmdb_ci_cluster sys_id ' + $SnowSysIdAvs)
      }
      else
      {
        Write-Verbose -Message ('PAT0013-SnowClusterCiCreationFailed: ' + $Result.RawContent)
        Return 'Failure'
      }
        # Create relationship CI -> Environment
        $Body = [xml]@"
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
            <soapenv:Header/>
            <soapenv:Body>
            <insert>
                <ci>$SnowSysIdAvs</ci>
                <environment>$ServerTier</environment>
            </insert>
            </soapenv:Body>
        </soapenv:Envelope>
"@
        $WebServiceUri = 'https://' + $Uri + '/cmdb_environment_to_ci.do?SOAP' 
        $Result = $null
        $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
        $SnowSysIdEnvCiRel = $Result.RawContent -split '<sys_id>'
        $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[1] -split '</sys_id>'
        $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[0]

        If ($SnowSysIdEnvCiRel.Length -ne 0)
        {
        Write-Verbose -Message ('PAT0013-SnowClusterCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
        }
        else
        {
        Write-Verbose -Message ('PAT0013-SnowClusterCiRelatedToEnvironmentFailed: ' + $Result.RawContent)
        Return 'Failure'
        }
    }
    else
    {
        Write-Verbose -Message ('PAT0013-SnowClusterCiExisting: ' + $SnowSysIdAvs)
    }


    ###########################################################################################################################################################
    #
    # Create cluster node (which is same name as server) - connecting server with cluster
    #
    ###########################################################################################################################################################
    $Body = [xml]@"
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_ci_cluster_node">
        <soapenv:Header/>
        <soapenv:Body>
          <insert>
            <name>$ServerName</name>
            <cluster>$AvailabilitySetName </cluster>
            <server>$ServerName</server>
          </insert>
        </soapenv:Body>
    </soapenv:Envelope>
"@
    $WebServiceUri = 'https://' + $Uri + '/cmdb_ci_cluster_node.do?SOAP' 
    $Result = $null
    $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
    $SnowSysIdClusterNode = $Result.RawContent -split '<sys_id>'
    $SnowSysIdClusterNode = $SnowSysIdClusterNode[1] -split '</sys_id>'
    $SnowSysIdClusterNode = $SnowSysIdClusterNode[0]

    If ($SnowSysIdClusterNode.Length -ne 0)
    {
    Write-Verbose -Message ('PAT0013-SnowClusterNodeCiCreated: cmdb_ci_cluster_node sys_id ' + $SnowSysIdClusterNode)
    }
    else
    {
    Write-Verbose -Message ('PAT0013-SnowClusterNodeCiCreationFailed: ' + $Result.RawContent)
    Return 'Failure'
    }

    # Create relationship CI -> Environment
    $Body = [xml]@"
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
        <soapenv:Header/>
        <soapenv:Body>
        <insert>
            <ci>$SnowSysIdClusterNode</ci>
            <environment>$ServerTier</environment>
        </insert>
        </soapenv:Body>
    </soapenv:Envelope>
"@
    $WebServiceUri = 'https://' + $Uri + '/cmdb_environment_to_ci.do?SOAP' 
    $Result = $null
    $Result = Invoke-WebRequest -Uri $WebServiceUri -Body $Body -ContentType 'text/xml' -Credential $CredentialsSnowUser -Method Post 
    $SnowSysIdEnvCiRel = $Result.RawContent -split '<sys_id>'
    $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[1] -split '</sys_id>'
    $SnowSysIdEnvCiRel = $SnowSysIdEnvCiRel[0]

    If ($SnowSysIdEnvCiRel.Length -ne 0)
    {
    Write-Verbose -Message ('PAT0013-SnowClusterNodeCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
    }
    else
    {
    Write-Verbose -Message ('PAT0013-SnowClusterNodeCiNodeRelatedToEnvironmentFailed: ' + $Result.RawContent)
    Return 'Failure'
    }
  }
  
  Return 'Success'
}  