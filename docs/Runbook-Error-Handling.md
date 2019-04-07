### Overview
* The focus should be on good loggin and not error handling. Implement error handling only on runbook level and not within runbooks - see below. The focus should be on re-startability of a runbook in case of an error condition. The runbook should fall into a suspend state not a failed state. Ensure that after an error condition code segement are not executed a second time - at least not code that would cause damage if executed twice. 
* If the called pattern returns data, e.g. query results, then no explicit error handling is implemented in the pattern. This is due to the fact that no data returned denotes an error. The types of errors can be both logical or infrastructure. A logical error results e.g. from a wrongly constructed query that doesn’t return results. An infrastructure error is due to a failure in the infrastructure, e.g. the table is not available. In this case no data is returned (as with the logical error) and an error will be logged in the runbooks log.
* If the called pattern doesn’t return data, e.g. a table insert, then the calling pattern will verbose-log either the error message returned by the called pattern or ‘Success’ (see below).
* Use try-catch to avoid Runbooks to fall into a failed state in case of errors during the execution. However, in PowerShell Workflows try-catch only works in inline scripts, also e.g. for REST calls this doesn’t work.
* Ensure there are no fake error log entries created. This would be e.g. when checking if an A-Record existing prior to registering it. This check would produce an error (A-Record not found) which in fact is not an error, but expected behavior.
* Types and combinations of errors:<br/>
  - Pattern 1: Infrastructure Error
  - Pattern 2: Calling runbook expecting data from called runbook: calling runbook returning data or null<br/>
               - log error and continue<br/>
	       - log error and don’t continue<br/>
  - Pattern 3: Calling runbook not expecting data from called runbook: calling runbook returning ‘Success’ or Error Code<br/>
	      - log error and continue<br/>
	      - log error and don’t continue<br/>
	      - Combination of above<br/>

### Checkpoint, Suspend and Resume of Workflows (also see Context setting)

* If an error is returned by the child runbook, the following options are available:<br/>
  - _Write-Error & Suspend workflow_ -> resume:	The runbook is suspended, but can be restarted manually after the error is remediated (e.g. Domain join not successful). If a resume is possible, then the TEC0005 pattern should be included to newly set the Azure Context (Suspend-Workflow results in the loss of the Azure Context). The workflow will continue running after the Suspend-Workflow<br/>
  - _Write-Error & Suspend workflow_ -> stop:	The runbook is suspended, but can't be restarted manually because it's not possible to remediate the error (e.g. OS version not retrieved from reference data table)<br/>
  - _Write-Error_  -> remediate later:	An error is written to the log, but the runbook continues without being suspended. The error can be remediated after the runbook is completed (e.g. creation of a CName).<br/>
  - _Technical error_ -> stop:	These are errors that are not dealt with in the code and result in a suspended workflow with an error. If that workflow is resumed, it resumes at the last Checkpoint-Workflow. This is different to above patterns where the workflow is manually suspended using a Suspend-Workflow.<br/>
* If there are problems with a runbook it's always suspended and never stopped. This to ensure that issues are investigated before a runbook is either manually restarted or stopped. 
* Checkpoints are only set where required, e.g. after activities that can't be repeated if a suspended workflow is resumed (e.g. create NIC). Since a Checkpoint-Workflow performs an implicit Suspend-Workflow the context is to be reset after a Checkpoint-Workflow. That context setting is only required if a runbook needs to be re-started. For simplicity of the code, that context setting is also performed during normal operations. 
* Once a suspended workflow is re-started in the portal, the resume activity depends on the reason for the suspend:<br/>
  - A Suspend-Workflow triggered the suspend -> the workflow is resumed immediately following the Suspend-Workflow - because that command also performs an implicit Checkpoint-Workflow<br/>
  - A workflow was suspended by Azure Automation for operational reasons, not because a Suspend-Workflow was issued -> the workflow restarts after the last Checkpoint-Workflow<br/>

### Pattern 1: Infrastructure Error
* The child runbook completes successfully
* Infrastructure type errors are logged in the context of the called runbook, these errors are created automatically. Meaning there is no dedicated error handling (e.g. verbose logging) required within the runbook to create this type of log entry
* If these errors lead to a suspension of the workflow a manual resume will re-start the workflow after the last Checkpoint-Workflow

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Runbook-Error-Handling-1.png" width="1000">

### Pattern 2: Data expected to be returned by child runbook
* Data is expected to be returned by the child runbook
* Error handling in the parent runbook is based on data returned or not.
  - If empty it could be a logical error, e.g. query is not correct.<br/>
  - If the result is empty due to an infrastructure error there will be an error logged (see Pattern 1).<br/>
* The absence of data returned by the child runbook is logged as an error by the parent runbook 
```powershell	
Write-Verbose -Message ('SOL0002-QueryTableVmSize: Start')
$VmSize = PAT0008-QueryTableVmSize -VmCpu $VmCpu -VmMemory $VmMemory  `
                                   -ServerTier $ServerTier `
                                   -HighPerformanceDisks $HighPerformanceDisks
If($VmSize -eq $null)
{
  Write-Error -Message ('SOL0002-QueryTableVmSize: Could not retrieve VM size')
  Suspend-Workflow
  TEC0005-SetAzureContext
} 
else
{
  Write-Verbose -Message ('SOL0002-VmSizeName (Standard_A2): ' + $VmSizeName)
  Write-Verbose -Message ('SOL0002-VmSizeShortName (A2): ' + $VmSizeShortName)
}
```

### Pattern 3: No data to be returned, but return code
* There is no data expected to be returned by the child runbook
* Therefore the success/failure is to be communicated by the child runbook by returning success or failure.
* The error with the details is logged by the child runbook
* If a failure is returned the parent runbook logs an error and the runbook might be suspended (see above).
* The behavior of try/catch is to catch terminating errors (exceptions). This means non-terminating (operational) errors inside a try block will not trigger a Catch. To catch all possible errors (terminating and non-terminating) add `-ErrorAction Stop`. In some cases it might be that the catch only works within an InlineScript when using Azure Automation. The catch with this is that Suspend-Workflow is not supported within an InlineScript. A solution might be to exit the InlineScript using Return and then handle the error..<br/>

**Parent runbook**
```powershell
$ReturnCode = PAT0017-SccmConfiguration -ServerName $ServerName   `
                                        -DomainZone $DomainZone
If ($ReturnCode -ne 'Success')
{
  Write-Error -Message ('SOL0001-AddServerToSccmAdGroup: ' + $ReturnCode)      
  Suspend-Workflow
  TEC0005-SetAzureContext
}
else
{
  Write-Verbose ('SOL0001-AddServerToSccmAdGroup: ' + $ReturnCode)
} 
```

**Child runbook**
```powershell
try
{
  $Result = Add-DnsServerResourceRecordA -ZoneName zone.com -Name $ServerName `
                                         -IPv4Address $PrivateIpAddress `
                                         -ComputerName $DomainControllerP `
	                                 -CreatePTR -Confirm: $false -ErrorAction Stop
  Write-Verbose -Message ('PAT0022-ARecordCreation: ' + "Created A-Record for $ServerName")
  Return 'Success'
}
catch
{
  Write-Error -Message ('PAT0022-ARecordCreationFailed: ' + ($Error[0] | Out-String))
  Return 'Failure'
} 
```
