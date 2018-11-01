###############################################################################################################################################################
# Creating the required CIs in the ServiceNow CMDB. This includes cmdb_ci_win/linux_server and in the case of an Availability Set the corresponding 
# cmdb_ci_cluster and cmdb_ci_cluster_node. In addition, all CIs are connected to the cmdb_ci_environment using the relationship table cmdb_environment_to_ci.
#
# Output:         'Success' or 'Failure'
# 
# Template:       PAT2900-SnowCmdbServerNew -DepartmentName $DepartmentName -ServerName $ServerName -ServerOwnerName $ServerOwnerName `
#                                           -Environment $Environment -ApplicationName $ApplicationName -ApplicationDescription $ApplicationDescription `
#                                           -ReqRitm $ReqRitm -Uri $Uri -AvailabilitySetName $AvailabilitySetName -PrivateIpAddress $PrivateIpAddress
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
    [Parameter(Mandatory = $false)][String] $DepartmentName = 'DEPT-1',
    [Parameter(Mandatory = $false)][String] $ServerName = 'azw1234',
    [Parameter(Mandatory = $false)][String] $ServerOwnerName = 'owern.name@customer.com',
    [Parameter(Mandatory = $false)][String] $Environment = 'Development',
    [Parameter(Mandatory = $false)][String] $ApplicationName = 'APP-1',
    [Parameter(Mandatory = $false)][String] $ApplicationDescription = 'APP-1 Database',
    [Parameter(Mandatory = $false)][String] $ReqRitm = 'REQ0098779 RITM0125931',
    [Parameter(Mandatory = $false)][String] $Uri = 'customerdev.service-now.com',
    [Parameter(Mandatory = $false)][String] $AvailabilitySetName = '',
    [Parameter(Mandatory = $false)][String] $PrivateIpAddress = '10.10.10.10'
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Compute, AzureRM.Resources, CimCmdlets
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #
  # Intialize parameters
  #
  #############################################################################################################################################################
  $CredentialsAutomationUser = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
  $CredentialsSnowUser = Get-AutomationPSCredential -Name 'CRE-AUTO-SnowTecUser'
  
  $ServerName = $ServerName.ToUpper()
  $AvailabilitySetName = $AvailabilitySetName.ToUpper()
  $StartDate = Get-Date -UFormat '%Y-%m-%d'
  $AssignmentGroup = 'Server Team'
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

  Write-Verbose -Message ('PAT2900-DepartmentName: ' + $DepartmentName)
  Write-Verbose -Message ('PAT2900-ServerName: ' + $ServerName)
  Write-Verbose -Message ('PAT2900-ServerOwnerName: ' + $ServerOwnerName)
  Write-Verbose -Message ('PAT2900-Environment: ' + $Environment)
  Write-Verbose -Message ('PAT2900-ApplicationName: ' + $ApplicationName)
  Write-Verbose -Message ('PAT2900-ApplicationDescription: ' + $ApplicationDescription)
  Write-Verbose -Message ('PAT2900-ReqRitm: ' + $ReqRitm)
  Write-Verbose -Message ('PAT2900-SerialNumber: ' + $SerialNumber)
  Write-Verbose -Message ('PAT2900-Uri: ' + $Uri)
  Write-Verbose -Message ('PAT2900-AvailabilitySetName: ' + $AvailabilitySetName)
  Write-Verbose -Message ('PAT2900-PrivateIpAddress: ' + $PrivateIpAddress)
  Write-Verbose -Message ('PAT2900-StartDate: ' + $StartDate)
  Write-Verbose -Message ('PAT2900-AssignmentGroup: ' + $AssignmentGroup)
  Write-Verbose -Message ('PAT2900-Manufacturer: ' + $Manufacturer)
  Write-Verbose -Message ('PAT2900-ModelId: ' + $ModelId)
  Write-Verbose -Message ('PAT2900-DeploymentMethod: ' + $DeploymentMethod)
  Write-Verbose -Message ('PAT2900-ServerCi: ' + $ServerCi)


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
          <manufacturer>$Manufacturer</manufacturer>
          <model_id>$ModelId</model_id>
          <name>$ServerName</name>
          <comments>$DeploymentMethod</comments>
          <po_number>$ReqRitm</po_number>
          <serial_number>$SerialNumber</serial_number>
          <short_description>$ApplicationDescription</short_description>
          <start_date>$StartDate</start_date>
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
    Write-Verbose -Message ('PAT2900-SnowWindowsServerCiCreated: ' + $ServerCi + ' sys_id ' + $SnowSysIdWindowsServer)
  }
  else
  {
    Write-Verbose -Message ('PAT2900-SnowWindowsServerCiCreationFailed: ' + $Result.RawContent)
    Return 'Failure'
  }
  
  # Create relationship CI -> Environment
  $Body = [xml]@"
  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
      <soapenv:Header/>
      <soapenv:Body>
        <insert>
          <ci>$SnowSysIdWindowsServer</ci>
          <environment>$Environment</environment>
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
    Write-Verbose -Message ('PAT2900-SnowWindowsServerCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
  }
  else
  {
    Write-Verbose -Message ('PAT2900-SnowWindowsServerCiRelatedToEnvironmentFailed: ' + $Result.RawContent)
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
        Write-Verbose -Message ('PAT2900-SnowClusterCiCreated: cmdb_ci_cluster sys_id ' + $SnowSysIdAvs)
      }
      else
      {
        Write-Verbose -Message ('PAT2900-SnowClusterCiCreationFailed: ' + $Result.RawContent)
        Return 'Failure'
      }
        # Create relationship CI -> Environment
        $Body = [xml]@"
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
            <soapenv:Header/>
            <soapenv:Body>
            <insert>
                <ci>$SnowSysIdAvs</ci>
                <environment>$Environment</environment>
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
        Write-Verbose -Message ('PAT2900-SnowClusterCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
        }
        else
        {
        Write-Verbose -Message ('PAT2900-SnowClusterCiRelatedToEnvironmentFailed: ' + $Result.RawContent)
        Return 'Failure'
        }
    }
    else
    {
        Write-Verbose -Message ('PAT2900-SnowClusterCiExisting: ' + $SnowSysIdAvs)
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
    Write-Verbose -Message ('PAT2900-SnowClusterNodeCiCreated: cmdb_ci_cluster_node sys_id ' + $SnowSysIdClusterNode)
    }
    else
    {
    Write-Verbose -Message ('PAT2900-SnowClusterNodeCiCreationFailed: ' + $Result.RawContent)
    Return 'Failure'
    }

    # Create relationship CI -> Environment
    $Body = [xml]@"
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://www.service-now.com/cmdb_environment_to_ci">
        <soapenv:Header/>
        <soapenv:Body>
        <insert>
            <ci>$SnowSysIdClusterNode</ci>
            <environment>$Environment</environment>
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
    Write-Verbose -Message ('PAT2900-SnowClusterNodeCiRelatedToEnvironment: cmdb_environment_to_ci sys_id ' + $SnowSysIdEnvCiRel)
    }
    else
    {
    Write-Verbose -Message ('PAT2900-SnowClusterNodeCiNodeRelatedToEnvironmentFailed: ' + $Result.RawContent)
    Return 'Failure'
    }
  }
  
  Return 'Success'
}  