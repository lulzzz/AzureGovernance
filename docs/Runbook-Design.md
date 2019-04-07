### Runbook Types I
Only PowerShell Workflows are used for the creation of runbooks, all other [runbook types](https://docs.microsoft.com/en-us/azure/automation/automation-runbook-types) are not used. While it is arguably more straight forward to work with PowerShell Scripts as compared to PowerShell Workflows there are some downsides to not using PowerShell Workflows:
* PowerShell Workflow runbooks can call other runbooks and have them executed in the same process space. The advantage of this approach is that all runbooks are [logging](#logging) into a single job in Azure Automation. This makes the logs more legible then having to combine logs from different jobs (one per runbook) in Azure Automation.
* PowerShell Workflow runbooks allow for the parallel execution of tasks. 

### Runbook Types II
**Solution Runbooks**<br/>
Solution runbooks are combining Pattern runbooks to implement e.g. an ITIL Service Request such as ‘Deploy Cosmos DB in Azure'. Ideally a Service Request triggered in the Service Request portal, maps to a Solution Runbook.<br/><br/>
Solution Runbooks mainly capture which Pattern runbooks are called an in what sequence, they should contain as little other logic as possibly. 

**Pattern Runbooks**<br/>
Pattern Runbooks are used to implemented re-usable functionality, such as ‘Configure DNS Entries’. They are designed very much like patterns in Object Oriented software development. They should be executable (and with that testable) independent of any other runbook, hence enabling changes on Pattern runbook level without re-testing all Solution runbooks. For that reason Pattern runbooks should set their own context and not rely on the context passed by the Solution runbook.<br/><br/>
They must have clearly defined input and output parameters. If they support different methods, a method/function type should be available (e.g. GetIpAddress, DeleteIpAddress). It might however be more efficient to simply create multiple Pattern runbooks instead of implementing methods.<br/><br/>
Runbooks must only produce output that is required by the calling runbooks. All other output is suppressed and if required logged (see Error Handling and Logging sections).<br/><br/>
Although it should be avoided, Pattern runbooks can call other Pattern runbooks. But they can’t call Solution runbooks.

**Technical Runbooks**<br/>
Technical runbooks are performing technical functions only, as opposed to business functions executed in the Pattern runbooks. An example is the importing of Runbooks from GitHub into an Azure Automation account. <br/>

### Calling Solutions Runbooks
Do not consolidate input parameters in the service portal but pass them 1:1 to the Solution. This way each attribute in the Service Request form is available 1:1 in the Solution. Example: if four disk sizes are entered in form, each in its own field, pass them as four parameters and not a single, comma delimited one.<br/><br/>
This simplifies trouble shooting because there is a 1:1:1 relationship of Form, Code in Portal and Solution. Also, the first function of a Solution is the parsing of the data passed-in by the Webhook and the creation and definition of additional variables not passed as parameters.<br/><br/>
Use generic names in the interface between the service portal and the Solution. This allows for the developers of the service portal and the Soluiton to assign independent names.<br/><br/>
Solutions can be called by use of [Azure Automation Webhook](https://docs.microsoft.com/en-us/azure/automation/automation-webhooks) or using the [REST API](https://docs.microsoft.com/en-us/rest/api/automation/job/create) - which requires an (Authorization Bearer Token). 

### Header
Below header is used on all runbooks:
* The Output section should list 'none' or the parameters returned (keep this short for proper display in [Visio diagram](https://github.com/fbodmer/AzureGovernance/wiki/Runbook-Overview))
* The Template section indicates how a PAT/TEC runbook is called by another runbook
* The Requirements section lists pre-conditions to executing this Runbook,
	
```powershell
###############################################################################################################################################################
# Execute queries against the reference table VmSize. This workflow also contains a section that is not actually part of the 
# workflow but is used to maintain the table. This way all information and code pertinent to VmSize is captured in this document.
# The table design is de-normalized because Azure Table queries support equal/greater/less only (no like, contains etc.)
#   
# Output:         Names of different VM sizes as used in Azure
#
# Requirements:   See Import-Module in code below / AD Security Groups
#
# Template:       PAT0008-QueryTableVmSize -VmCpu $VmCpu -VmMemory $VmMemory -ServerTier $ServerTier -HighPerformanceDisks $HighPerformanceDisks
#
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
```

### Workflow Definition  
* PowerShell has long supported the definition of `OutputType` in functions and cmdlets with the use of the OutputType attribute. This attribute has no effect during runtime, and instead has been provided as a way for tools to learn, at design time, the object types that cmdlets output without having to run them. OutputType can be used in PowerShell Workflow, and you should include OutputType in runbooks that have output - it might be a required attribute in the future. 
* Use `$false` for parameters as this simplifies testing and the validation of input parameters should be performed in the Service Request form. 
* Place entire Pattern and Technical runbook into `InlineScript`. Don't do so for Solution runbooks as they are calling other runbooks - which is not supported in InlineScripts. There are too many issues when not using InlineScript. This helps when working with code snippets. It also solves issues with serialization. 
* Place `Using:` at top of script and before `Write-Verbose`. This ensures the logging is displaying what will be used within the InlineScript.
* Define default values as this is useful when testing the runbook, but make sure not to use values that could cause damage in production.
* `Import-Module` avoids verbose clutter in the Azure Automation log.

```powershell
workflow PAT0004-ReserveTableIpAddress
{
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory=$false)][String] $SubnetName  = "Frontend-CB",
        [Parameter(Mandatory=$false)][String] $ServerNicName  = "li-testservernic1"
        [Parameter(Mandatory=$false)][String] $ServerNicName  = "li-testservernic1"
        [Parameter(Mandatory=$false)][String] $ServerNicName  = "li-testservernic1"
    )
    #############################################################################################################################################################
    #  
    # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
    #
    #############################################################################################################################################################
    InlineScript
    {
      $VerbosePreference = 'SilentlyContinue'
      $Result = Import-Module AzureRM.RecoveryServices, AzureRM.RecoveryServices.Backup
      $VerbosePreference = 'Continue'
    }
    TEC0005-AzureContextSet 
 
    InlineScript
    {
        $SubnetName = $Using:SubnetName
        $ServerNicName = $Using:ServerNicName

        Write-Verbose -Message ('PAT0004-SubnetName: ' + $SubnetName)
        Write-Verbose -Message ('PAT0004-ServerNicName: ' + $ServerNicName)
```

### Include all information in Runbook
Any code after Return is for purposes not required by the runbook execution. Could also include parameter values and cmdlets for testing. Mark section as comments to avoid issues during compilation of the Runbook.

```powershell
...
Return
    #######################################################################################################################################################
    #
    # Below section is for maintenance purposes only, e.g. in case the table needs to be restored or table entities changed.
    # This is performed by deleting and re-creating the entire table 
    #
    #######################################################################################################################################################
    <# Delete and re-create table
    $TableName = "VmSize"
    ...
    #>
```

### Azure Context for Account and Storage
See [TEC0005-AzureContextSet](TEC0005) for details.

### Remoting and User context switch
Best practice is to store credentials in an Azure Automation asset and not in the runbooks - retrieve using Get-AutomationPSCredential.
Using `localhost` instead of a remote host will essentially perform a user context switch on the local server. Using a hostname will do both, user context switch and remoting into another server.

```powershell
workflow Test1
{
    $User = ‘domain\user'
    $Password = ConvertTo-SecureString ‘password' -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($User, $Password)
    $Credentials = Get-AutomationPSCredential -Name “AutomationVariable" 
    hostname
    [Environment]::UserName
    InlineScript
    {
        hostname
        [Environment]::UserName
    }  -PSCredential $Credentials -PSComputerName localhost
    hostname
    [Environment]::UserName
}
```

### Logging
**Overview**
* All runbooks use Azure Automation `verbose logging` for logging purposes. Set `$VerbosePreference = 'Continue'` in all runbooks.
* In Azure Automation activate `Verbose logging` only – don’t use any other logging types, they are for different purposes. By default all Azure Automation logging is off, this is because Microsoft recommends verbose logging for troubleshooting purposes only. Activate verbose logging in all environments on all runbooks. 
* The verbose setting in the runbooks has no impact on published runbooks, but it does so on draft runbooks. 
* Use following logging in the runbooks:
`Write-Verbose 'PAT0006-Table: $Date'` -> Precede the log attribute name with the id of the runbook (e.g. PAT0006),     this helps with nested logging and parsing of the logs
`Write-Verbose ("PAT0006-Credentials: " + ($Credentials | Out-String))` -> Output of Objects in clear text
`Write-Verbose -Message ('SOL0007-VmObject: ' + ($Vm | ConvertTo-Json))` -> Output of large objects
* When executing a remote session e.g. using InlineScript, then `$VerbosePreference = 'Continue'` needs to be set for the remote session.

**Example**
```powershell
$VmSize = PAT0008-QueryTableVmSize -VmCpu $VmCpu -VmMemory $VmMemory -ServerTier $ServerTier -HighPerformanceDisks $HighPerformanceDisks
$VmSizeName = $VmSize.VmSizeName
$VmSizeShortName = $VmSize.VmSizeShortName
Write-Verbose ("SOL0001-VmSizeName (Standard_A2): " + $VmSizeName)
Write-Verbose ("SOL0001-VmSizeShortName (A2): " + $VmSizeShortName) 

workflow PAT0008-QueryTableVmSize
{
    param
    (
    [Parameter(Mandatory=$false)][String]$VmCpu = "2",
    [Parameter(Mandatory=$false)][String]$VmMemory = "7",
    [Parameter(Mandatory=$false)][String]$ServerTier = "Production",
    [Parameter(Mandatory=$false)][String]$HighPerformanceDisks = "Yes"
    )
    InlineScript
    {
        $VmCpu = $Using:VmCpu
        $VmMemory = $Using:VmMemory
        $ServerTier = $Using:ServerTier
        $HighPerformanceDisks = $Using:HighPerformanceDisks
        $VerbosePreference = "Continue"
        Write-Verbose ("PAT0008-VmCpu: " + $VmCpu)
        Write-Verbose ("PAT0008-VmMemory: " + $VmMemory)
        Write-Verbose ("PAT0008-ServerTier: " + $ServerTier)
        Write-Verbose ("PAT0008-HighPerformanceDisks: " + $HighPerformanceDisks)
        ...
        $TableName = "VmSize"
        $Date = Get-Date -UFormat "%Y%m%d"     
        # Used for temporal table query
        Write-Verbose "PAT0008-TableName: $TableName"
        Write-Verbose "PAT0008-Date: $Date"  
```

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Runbook-Design-1.png" width="500"><br/><br/>

**Loading PowerShell Modules**<br/>
Manually load all required PowerShell modules as this reduces clutter in the Azure Automation verbose log. The goal is that only entries generated by the runbooks show up in the Azure Automation verbose log. 

The module AzureAutomationAuthoringToolkit doesn't have to be loaded, it doesn't even have to be installed on the Azure workers or the Hybrid Runbook workers for the Runbooks to execute - even though Get-AutomationVariable is part of AzureAutomationAuthoringToolkit. 

```powershell
#############################################################################################################################################################
#  
# Import modules prior to Verbose setting to avoid clutter in Azure Automation log
#
#############################################################################################################################################################
 
InlineScript
{
  $VerbosePreference = 'SilentlyContinue'
  $Result = Import-Module AzureRM.Profile, AzureRM.Storage
  $VerbosePreference = 'Continue'
}
```
To suppress all verbose logging (not just the logging concerning the loading of the modules) below is required for all Automation Asset commands - but only when used in an InlineScript. It's not required when used directly in the workflow.

```powershell
InlineScript
{
  $VerbosePreference = 'SilentlyContinue'
  $SubscriptionName = Get-AutomationVariable -Name 'VAR-AUTO-SubscriptionName' 
  $VerbosePreference = 'Continue'
}
```


### Retrieving logs

**Get latest job - last modified**<br/>
```powershell
    $AutomationAccountName = Get-AutomationVariable VAR-AUTO-AutomationAccountName
    $AutomationAccountResourceGroupName = Get-AutomationVariable VAR-AUTO-CoreResourceGroup
    $JobData = Get-AzureRmAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationAccountResourceGroupName | 
    Sort-Object -Property LastModifiedTime | Select-Object -Last 1 | 
    Get-AzureRmAutomationJobOutput |
    Where-Object -FilterScript {($_.Summary -like '*PAT0*') -or ($_.Summary -like '*SOL0*') -or ($_.Summary -like '*TEC0*') -or ($_.Type -eq 'Error') -or ($_.Type -eq 'Warning')} |
    Get-AzureRmAutomationJobOutputRecord
    $NumberOfEntities = $JobData.count
    $Counter = 0
    $Output = do
    {
        if ($JobData.Type[$Counter] -eq 'Verbose')
        {
          [PSCustomObject]@{LocalDateTime = $JobData[$Counter].Time.DateTime;
                            MessageType =  $JobData[$Counter].Type;
                            Message = (($JobData[$Counter].Value.Message) -split 'localhost]\:')[1]}
        }
        else
        {
          [PSCustomObject]@{LocalDateTime = $JobData[$Counter].Time.DateTime;
                            MessageType =  $JobData[$Counter].Type;
                            Message = $JobData[$Counter].Value.Exception.Message}
        }
        $Counter = $Counter+1
    }
    until ($Counter -ge $NumberOfEntities)
    $Output | Out-GridView
```

**Get specific job - by entering job ID**<br/>
```powershell
    $JobId = Read-Host 'Job ID'
    $AutomationAccountName = Get-AutomationVariable VAR-AUTO-AutomationAccountName
    $AutomationAccountResourceGroupName = Get-AutomationVariable VAR-AUTO-CoreResourceGroup
    $JobData = Get-AzureRmAutomationJob -Id $JobId -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationAccountResourceGroupName | 
    Get-AzureRmAutomationJobOutput |
    Where-Object -FilterScript {($_.Summary -like '*PAT0*') -or ($_.Summary -like '*SOL0*') -or ($_.Summary -like '*TEC0*') -or ($_.Type -eq 'Error') -or ($_.Type -eq 'Warning')} |
    Get-AzureRmAutomationJobOutputRecord
    $NumberOfEntities = $JobData.count
    $Counter = 0
    $Output = do
    {
        if ($JobData.Type[$Counter] -eq 'Verbose')
        {
          [PSCustomObject]@{LocalDateTime = $JobData[$Counter].Time.DateTime;
                            MessageType =  $JobData[$Counter].Type;
                            Message = (($JobData[$Counter].Value.Message) -split 'localhost]\:')[1]}
        }
        else
        {
          [PSCustomObject]@{LocalDateTime = $JobData[$Counter].Time.DateTime;
                            MessageType =  $JobData[$Counter].Type;
                            Message = $JobData[$Counter].Value.Exception.Message}
        }
        $Counter = $Counter+1
    }
    until ($Counter -ge $NumberOfEntities)
    $Output | Out-GridView
```
