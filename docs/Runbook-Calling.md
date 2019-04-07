### Overview
* Create a log entry before calling the child runbook and another one after the call is completed. If no data is returned then use Successful, if data is returned make sure it is output as text and not as object, to ensure it's legible in the log. 
* Output all parameters passed to the child runbook in verbose mode. This helps in troubleshooting.
* Return the result from the InlineScript, which will also return the result from the child runbook to the main runbook
* Checkpoint the workflow after a child runbook has been called -> see [Context setting](TEC0005) for details.
* Child runbooks should only output what is returned to the calling runbook. All other output must be suppressed. 
* Output should be performed by using the same variable name as what is used in the calling runbook. This facilitates manual testing in ISE. When manually executing a runbook in ISE the output will be available in the same variable that is used by the calling runbook. When testing in ISE all execution is in the same PowerShell runspace.

### Returning 'Success' or 'Failure'
Returning  'Success' or 'Failure' and in case of a failure also to error code.

**Parent Runbook**<br/>
```powershell
Write-Verbose -Message ('SOL0002-ReCreateDns: Start')
$Result = PAT0022-CreateDns -ServerName $ServerName -PrivateIpAddress $PrivateIpAddress -DomainZone $DomainZone `
                            -ApplicationDnsAliasFqdn $ApplicationDnsAliasFqdn
If ($Result -ne 'Success')
{
  Write-Error -Message ('SOL0002-UpdateDnsFailed: ' + $Result)
  Suspend-Workflow
}
else
{ 
  Write-Verbose -Message ('SOL0002-UpdateDns: A-Record and Cnames re-created successfully')
} 
```

**Child Runbook**<br/>
```
try
{
  $Result = Add-DnsServerResourceRecordA -ZoneName hilti.com -Name $ServerName -IPv4Address $PrivateIpAddress `
                                         -ComputerName $DomainControllerP `
	                                 -CreatePTR -Confirm: $false -ErrorAction Stop
  Write-Verbose -Message ('PAT0022-ARecordCreation: ' + "Created new A-Record for $ServerName in hilti.com zone")
  Return 'Success'
}
catch
{
  Write-Error -Message ('PAT0022-ARecordCreation: A-Record not created ' + ($Error[0] | Out-String))
  Return 'Failure'
} 
```

### Returning a Value
**Parent Runbook**<br/>
```powershell
Write-Verbose ("SOL0001-RetrievePrivateIpAddress: Start")
$PrivateIpAddress = PAT0004-ReserveTableIpAddress -SubnetName $SubnetName -ServerNicName $ServerNicName `
                                                  -ServerName $ServerName -DomainZone $DomainZone
If ($PrivateIpAddress -eq $null)
{
  Write-Error -Message ("SOL0001-RetrievePrivateIpAddress: Failure")
  Suspend-Workflow
}
Write-Verbose ("SOL0001-RetrievePrivateIpAddress: " + ($PrivateIpAddress|Out-String))
Checkpoint-Workflow
```

**Child Runbook**
```powershell
workflow PAT0004-ReserveTableIpAddress
{
  [OutputType([string])]

  param
  (
    [Parameter(Mandatory = $false)][String] $SubnetName  = 'Frontend-DEV',
    [Parameter(Mandatory = $false)][String] $DomainZone = 'hiltiq.com',
    [Parameter(Mandatory = $false)][String] $ServerNicName  = 'li-testtestc01nic1',
    [Parameter(Mandatory = $false)][String] $ServerName  = 'li-testtestc01'
  )

  $VerbosePreference = 'Continue'
  InlineScript
  {
    $SubnetName = $Using:SubnetName
    $DomainZone = $Using:DomainZone
    $ServerNicName = $Using:ServerNicName
    $ServerName = $Using:ServerName
    
    Write-Verbose -Message ('PAT0004-SubnetName: ' + $SubnetName)
    Write-Verbose -Message ('PAT0004-DomainZone: ' + $DomainZone) 
    Write-Verbose -Message ('PAT0004-ServerNicName: ' + $ServerNicName) 
    Write-Verbose -Message ('PAT0004-ServerName: ' + $ServerName) 
    ...

    Return $PrivateIpAddress
  }
```

### Passing an Array
In the calling runbook define and create an array, pass a single parameter to the child runbook. 

**Parent Runbook**<br/>
```powershell
workflow test
{ 
  $ApplicationDnsAliasFqdn = @()
  $ApplicationDnsAliasFqdn = $ApplicationDnsAliasFqdn + 'alias1.us.hiltiq.com'
  $ApplicationDnsAliasFqdn = $ApplicationDnsAliasFqdn + 'alias2.hiltiq.com'
  PAT0022-CreateDns -ServerName $ServerName -PrivateIpAddress $PrivateIpAddress -DomainZone $DomainZone `
                    -ApplicationDnsAliasFqdn $ApplicationDnsAliasFqdn
} 
```

**Child Runbook**<br/>
```powershell
workflow PAT0022-CreateDns
{
   param
  (
    [string][Parameter(Mandatory = $false)] $ServerName = 'li-testtestc01',
    [string][Parameter(Mandatory = $false)] $PrivateIpAddress = '192.168.1.2',
    [string][Parameter(Mandatory = $false)] $DomainZone = 'hiltiq.com',
    [array] [Parameter(Mandatory = $false)]  $ApplicationDnsAliasFqdn  # Can't define default, in portal enter as: ['alias1.hilti.com','alias2.hilti.com']
  ) 
```

### Passing hash table as object using Start-AzureRmAutomationRunbook<br/>
Define a hash table and pass as -Parameter to the child runbook. In the child runbook each individual entry of the hash table must be defined as a parameter of type object. The number of entries in the hash table and the number of defined parameters in the child runbook must correspond. 

**Parent Runbook**<br/>
```powershell
workflow TEC0001-MonitorAssessments
{
  $AssessmentData = @{
                       'AssessmentDataId' = $AssessmentDataId
                       'AssessmentDataStatus' = $AssessmentDataStatus
                       'ServerTier' = $ServerTier
                       'VmName' = $VmName
                     }
  $AutomationAccountName = Get-AutomationVariable -Name 'VAR-AUTO-AutomationAccountName'
  $RgNameCore = Get-AutomationVariable -Name 'VAR-AUTO-CoreResourceGroup'
  $HybridWorkerName = Get-AutomationVariable -Name 'VAR-AUTO-HybridWorkerName'
  $StartedRunbookJob = Start-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName `
	                                                     -Name SOL0002-MigrateServer `
	                                                     -ResourceGroupName $RgNameCore `
	                                                     -RunOn $HybridWorkerName `
	                                                     -Parameter $AssessmentData 
  ...
```

**Child Runbook**<br/>
```powershell
workflow SOL0002-MigrateServer
{
  param
  (
    [Parameter(Mandatory = $false)][object] $AssessmentDataId,
    [Parameter(Mandatory = $false)][object] $AssessmentDataStatus,
    [Parameter(Mandatory = $false)][object] $ServerTier,
    [Parameter(Mandatory = $false)][object] $VmName         # In portal enter as: {“StringParam”:”Joe”,”IntParam”:42,”BoolParam”:true}
  ) 
```

### Returning parameters from multiple InlineScript in a single child Runbook
* Return output from each InlineScript in an array for later use on workflow level.
* In a standard workflow the output of all InlineScripts is combined/appended to a single array in system variable `$output`. 
* In an Azure Automation workflow this is not the case as each InlineScript is executed in its own sandbox. Combine the output off all individual InlineScript in a Workflow into a single array. This array is then passed to the calling workflow.
* The array will still be displayed as outlined in below Azure Automation Workflow example. But it is in fact a single array.
```powershell
Standard Workflow output        Azure Automation Workflow output
Name             Value          Name                      Value      
1                A              1                         A
2                B              Name                      Value 
                                2                         B
```
<img src="https://github.com/fbodmer/AzureGovernance/wiki/Runbook-Calling-1.png" width="800">



### Returning an Object
````powershell
workflow PAT0003-CreateDisk
{
  param
  (
    [Parameter(Mandatory=$false)][String] $RgName = 'AMS-DEV-TEST-RG01',
    [Parameter(Mandatory=$false)][String] $VmName = 'li-felixtestd99',
    [Parameter(Mandatory=$false)][Int]    $DataDiskTotalSize = 400,
    [Parameter(Mandatory=$false)][String] $HighPerformanceDisks = 'Yes',
    [Parameter(Mandatory=$false)][String] $StorageAccountNamePrefix = 'amsdevtest'
  )
  InlineScript
  {
    ...
    $DiskUri = [PSCustomObject]@{DiskName = "$VmName-osDisk"; DiskType = 'OS'}
    $DiskUri
  }
```
