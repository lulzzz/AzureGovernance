###############################################################################################################################################################
# Customizes the installed OS.
# 
# Error Handling: There is no error handling available in this pattern.
#
# Output:         Success / Failure
#
# Requirements:   DnsClient, NetAdapter, NetSecurity, NetTCPIP
#
# Template:       PAT0203-ComputerWindowsServerCustomize -ServerName $ServerName -ServerDescription $ServerDescription -IpAddress $IpAddress `
#                                                        -SubnetPrefix $SubnetPrefix -DefaultGateway $DefaultGateway -DnsServer1 $DnsServer1 `
#                                                        -DnsServer2 $DnsServer2 -DnsServer3 DnsServer3
#
# Change log:
# 1.0             First version
#
###############################################################################################################################################################
workflow  PAT0203-ComputerWindowsServerCustomize
{
  [OutputType([string])] 

  param
  (
    [Parameter(Mandatory = $False)][string] $ServerName = '',
    [Parameter(Mandatory = $False)][string] $ServerDescription = '',
    [Parameter(Mandatory = $False)][string] $IpAddress = '',
    [Parameter(Mandatory = $False)][string] $SubnetPrefix = '',
    [Parameter(Mandatory = $False)][string] $DefaultGateway = '',
    [Parameter(Mandatory = $False)][string] $DnsServer1 = '',
    [Parameter(Mandatory = $False)][string] $DnsServer2 = '',
    [Parameter(Mandatory = $False)][string] $DnsServer3 = ''
  )

  $VerbosePreference = 'Continue'

  TEC0005-SetAzureContext

  $Credentials = Get-AutomationPSCredential -Name 'CRE-AUTO-LocalAdmin'

  ###########################################################################################################################################################
  #
  # Ensure server is running
  #
  ###########################################################################################################################################################
  try
  {
    New-PSSession -ServerName $ServerName -Credentials $Credentials
    Remove-PSSession
  }
  catch
  {
    Write-Error -Message ('PAT0203-RemotePowerShellToServerNotWorking')
    Return 'Failure'
  }

  $Result = InlineScript
  {
    $ServerName = $Using:ServerName
    $ServerDescription = $Using:ServerDescription
    $IpAddress = $Using:IpAddress
    $SubnetPrefix = $Using:SubnetPrefix
    $DefaultGateway = $Using:DefaultGateway
    $DnsServer1 = $Using:DnsServer1
    $DnsServer2 = $Using:DnsServer2
    $DnsServer3 = $Using:DnsServer3

    Write-Verbose -Message ('PAT0203-ServerName' + $ServerName)
    Write-Verbose -Message ('PAT0203-ServerDescription' + $ServerDescription)
    Write-Verbose -Message ('PAT0203-IpAddress' + $IpAddress)
    Write-Verbose -Message ('PAT0203-SubnetPrefix' + $SubnetPrefix)
    Write-Verbose -Message ('PAT0203-DefaultGateway' + $DefaultGateway)
    Write-Verbose -Message ('PAT0203-DnsServer1' + $DnsServer1)
    Write-Verbose -Message ('PAT0203-DnsServer2' + $DnsServer2)
    Write-Verbose -Message ('PAT0203-DnsServer3' + $DnsServer3)

    $Credentials = Get-AutomationPSCredential -Name 'CRE-AUTO-LocalAdmin'


    ###########################################################################################################################################################
    #
    # Configure NIC
    #
    ###########################################################################################################################################################
    $Nic = Get-NetAdapter

    # Reset Adapter 
    netsh interface ip set winsservers name=$Nic.ifIndex source=dhcp
        
    # Reset DNS
    Set-DnsClientServerAddress -InterfaceIndex $Nic.ifIndex -ResetServerAddresses
        
    # Reset IP, Subnetz, Gateway
    Remove-NetRoute -InterfaceIndex $Nic.ifIndex -Confirm $false -ErrorAction SilentlyContinue
    route delete 0.0.0.0 > $null
    Set-NetIPInterface -InterfaceIndex $Nic.ifIndex -Dhcp Enabled

    # Configure NIC - IP, Subnet, Gateway
    Set-NetIPInterface -Dhcp Disabled
    New-NetIPAddress -InterfaceIndex  $Nic.ifIndex -IPAddress $IpAddress -PrefixLength $SubnetPrefix -DefaultGateway $DefaultGateway 
        
    # Configure DNS
    Set-DnsClientServerAddress -InterfaceIndex $Nic.ifIndex -ServerAddresses ($DnsServer1,$DnsServer2,$DnsServer3)

    Write-Verbose -Message ('PAT0203-NicConfigured')


    ###########################################################################################################################################################
    #
    # Set Computer Description
    #
    ###########################################################################################################################################################
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters" -Name "srvcomment" -Value "$ServerDescription"
    Write-Verbose -Message ('PAT0203-ComputerDescriptionSet')


    ###########################################################################################################################################################
    #
    # Set pagefile size - memory * 1.5 but not more than 8192 MB
    #
    ###########################################################################################################################################################
    $PageFile = Get-WmiObject -class Win32_PageFileSetting
    $Ram = Get-WmiObject Win32_OperatingSystem | Select-Object TotalVisibleMemorySize
    $Ram = ($Ram.TotalVisibleMemorySize / 1kb).tostring("00")
    $Ram = [int]$Ram
    $PageSize = [int]($Ram * 1.5)
    if($PageSize -gt 8192)
    {
      $PageSize = 8192
    }
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value "c:\pagefile.sys $PageSize $PageSize"
    Write-Verbose -Message ('PAT0203-PageFileSizeSet')


    ###########################################################################################################################################################
    #
    # Set screen resolution
    #
    ###########################################################################################################################################################
    Set-DisplayResolution -Width 1024 -Height 768 -Force
    Write-Verbose -Message ('PAT0203-DisplayResolutionSet: 1024x768')


    ###########################################################################################################################################################
    #
    # Deactivate Windows firewall
    #
    ###########################################################################################################################################################
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    Write-Verbose -Message ('PAT0203-WindowsFirewalDisabled')


    ###########################################################################################################################################################
    #
    # Empty event log
    #
    ###########################################################################################################################################################
    $Logs = Get-EventLog -List 
    ForEach ($Log in $Logs)
    {
      Clear-EventLog -Log $Log.LogDisplayName -ErrorAction SilentlyContinue
    }
    Write-Verbose -Message ('PAT0203-EventLogEmptied')


    ###########################################################################################################################################################
    #
    # Integrate change log
    #
    ###########################################################################################################################################################
    $ChangeLogShare = '\\app-prod-ChangeLog.irdom.net\ServerLog'
    $ChangeLogTemplate = $ChangeLogShare + '\Vorlage.txt'

#    #Ablageordner festlegen ??? replace this with call to SQL DB
#    $domainname = $env:userdomain
#    switch ($domainname){
#            "ARUDINT" {$TargetFolder = "ARU"}
#		         "BAL" {$TargetFolder = "Balgrist"}
#            "CARE" {$TargetFolder = "CARE"}
#            "GZODOM" {$TargetFolder = "GZO"}
#            "HDLZ" {$TargetFolder = "HDLZ"}
#            "IRDOM" {$TargetFolder = "Irdom"}
#            "LIMMI" {$TargetFolder = "Limmi"}
#            "LOGICARE" {$TargetFolder = "Logi"}
#            "GKH" {$TargetFolder = "See"}
#            "ZLZ" {$TargetFolder = "ZLZ"}
#            default {$TargetFolder = $null}
#        }


    # Create change log 
    $ChangeLog = "$ChangeLogShare\$TargetFolder\$ServerName.txt"
    Copy-Item $ChangeLogTemplate -Destination $ChangeLog

    # Add change log to startup
    $StartupFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $StartupScript = $StartupFolder+"\ChangeLog.bat"
    "start notepad.exe $ChangeLog" | Out-File -FilePath $StartupScript -Encoding ascii
    Write-Verbose -Message ('PAT0203-ChangeLogIntegrated')


    ###########################################################################################################################################################
    #
    # Windows Update
    #
    ###########################################################################################################################################################
    $ProxyRegKey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $ProxyScript="http://wpad.irdom.net/LGCProxy.pac"
    
    Set-ItemProperty -path $ProxyRegKey AutoConfigURL -value $ProxyScript
    Set-ProxySettings -AutomaticDetect $false -UseAutomaticConfigurationScript $true
    Get-WUInstall -AcceptAll -IgnoreReboot
    Remove-ItemProperty -path $ProxyRegKey AutoConfigURL
    Set-ProxySettings -UseAutomaticConfigurationScript $false 
    Write-Verbose -Message ('PAT0203-WindowsUpdateExecuted')
    

    ###########################################################################################################################################################
    #
    # Reboot server
    #
    ###########################################################################################################################################################
    Write-Verbose -Message ('PAT0203-InitiateReboot')
    Restart-Computer -ServerName $ServerName -Wait
    Start-Sleep -Seconds 30
    try
    { 
      Test-Connection $ServerName
    }
    catch
    {
      Write-Error -Message ('PAT0203-ServerNotRestarting: ' + $ServerName)
      Return 'Failure'
    }
    Return 'Success'
  } -PSComputerName $ServerName -PSCredential $Credentials
}