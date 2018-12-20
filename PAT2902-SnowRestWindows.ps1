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
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue03 = 'Windows Server 2016',              # $RequiredOperatingSystem - 'Windows Server 2012 R2' / 'Windows Server 2016'
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue04 = 'Development',                      # $Environment - 'Development' / 'Production'
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue05 = 'CH',                               # $CountryShortCode 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue06 = 'azw',                              # $ServerNameIndividual
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue07 = 'qzw##',                            # $ServerNameNoCounter
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue08 = 'app1',                             # $ApplicationDnsAliasName
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue09 = 'app1.customer.com',                # $ApplicationDnsAliasFqdn
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue10 = 'APP-1',                            # $ApplicationName
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue11 = 'Test Server for automation',       # $ApplicationDescription
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue12 = 'No',                               # $HighPerformanceDisks
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue13 = 'No',                               # $SqlServerInstallation
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue14 = '127 GB',                           # $SystemDiskSizeTemp1
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue15 = '100 GB',                           # $DataDisk1SizeTemp1
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue16 = '200 GB',                           # $DataDisk1SizeTemp2
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue17 = '300 GB',                           # $DataDisk1SizeTemp3
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue18 = '400 GB',                           # $DataDisk1SizeTemp4
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue19 = '1,3.5',                            # $VmCpuMemory 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue20 = 'No',                               # $BackupType  
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue22 = '',                                 # $LocalAdminUsers 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue25 = 'No',                               # $PowerOffWeekends 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue26 = 'No',                               # $PowerOffNonBusinessHours 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue27 = 'UTC+01:00',                        # $ApplicationTimeZone 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue34 = 'ServerTeam-Admins',                # $LocalAdminGroups 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue35 = '635df14f4f2b52005633bc511310c756', # $SnowRitmSysId 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue36 = 'Frontend',                         # $SubnetName - 'Mgmt' / 'Frontend'
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue37 = 'REQ0098779 RITM0125931',           # $ReqRitm 
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue38 = 'customerdev.service-now.com',      # $Uri
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue39 = 'No',                               # $AvailabilitySetRequired  - 'Yes' / 'No'
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue40 = 'No',                               # $AvailabilitySetExisting  - 'Yes' / 'No'
    [Parameter(Mandatory = $false)][String]$SnowAttributeValue41 = ''                                  # $AvailabilitySetName (existing AVS)
  )

  $JSONBody = @"
    {
        "SnowAttribute01":"$SnowAttributeValue01",
        "SnowAttribute02":"$SnowAttributeValue02",
        "SnowAttribute03":"$SnowAttributeValue03",
        "SnowAttribute04":"$SnowAttributeValue04",
        "SnowAttribute05":"$SnowAttributeValue05",
        "SnowAttribute06":"$SnowAttributeValue06",
        "SnowAttribute07":"$SnowAttributeValue07",
        "SnowAttribute08":"$SnowAttributeValue08",
        "SnowAttribute09":"$SnowAttributeValue09",
        "SnowAttribute10":"$SnowAttributeValue10",
        "SnowAttribute11":"$SnowAttributeValue11",
        "SnowAttribute12":"$SnowAttributeValue12",
        "SnowAttribute13":"$SnowAttributeValue13",
        "SnowAttribute14":"$SnowAttributeValue14",
        "SnowAttribute15":"$SnowAttributeValue15",
        "SnowAttribute16":"$SnowAttributeValue16",
        "SnowAttribute17":"$SnowAttributeValue17",
        "SnowAttribute18":"$SnowAttributeValue18",
        "SnowAttribute19":"$SnowAttributeValue19",
        "SnowAttribute20":"$SnowAttributeValue20",
        "SnowAttribute22":"$SnowAttributeValue22",
        "SnowAttribute25":"$SnowAttributeValue25",
        "SnowAttribute26":"$SnowAttributeValue26",
        "SnowAttribute27":"$SnowAttributeValue27",
        "SnowAttribute34":"$SnowAttributeValue34",
        "SnowAttribute35":"$SnowAttributeValue35",
        "SnowAttribute36":"$SnowAttributeValue36",
        "SnowAttribute37":"$SnowAttributeValue37",
        "SnowAttribute38":"$SnowAttributeValue38",
        "SnowAttribute39":"$SnowAttributeValue39",
        "SnowAttribute40":"$SnowAttributeValue40",
        "SnowAttribute41":"$SnowAttributeValue41"
    }
"@


  $WebHook = Get-AutomationVariable -Name VAR-AUTO-SOL0001WebHook

  # Invokes using the Hybrid Runbook Worker 
  Invoke-RestMethod -Uri $WebHook `
                    -Body $JSONBody `
                    -Method Post 

}
