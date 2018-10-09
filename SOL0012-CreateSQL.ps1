###############################################################################################################################################################
# Creates a new instance of an Azure Analysis Service based on the input parameters.
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   ???
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0012-CreateSQL
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ServiceRequester = 'felix.bodmer@felix.bodmer.name',
    [Parameter(Mandatory=$false)][String] $Region = 'West US',
    [Parameter(Mandatory=$false)][String] $Environment = 'Test',
    [Parameter(Mandatory=$false)][String] $RgName = 'wus-te-rg-data-01',
    [Parameter(Mandatory=$false)][String] $SqlDbNameIndividual = 'db',
    [Parameter(Mandatory=$false)][String] $SqlServerNameIndividual = 'ref',
    [Parameter(Mandatory=$false)][String] $SqlServerName = 'wus-te-sdb-ref-01',
    [Parameter(Mandatory=$false)][String] $FirewallStartIpAddress = '213.55.184.217',
    [Parameter(Mandatory=$false)][String] $FirewallEndIpAddress = '213.55.184.217',
    [Parameter(Mandatory=$false)][String] $WorkSpaceId = '/subscriptions/ae747229-5897-4d01-93bb-284e69893c47/resourceGroups/wus-pr-rg-dba-01/providers/Microsoft.OperationalInsights/workspaces/felwusprdba01',
    [Parameter(Mandatory=$false)][String] $Allocation = 'Business',
    [Parameter(Mandatory=$false)][String] $Allocation_Group = 'DIA_HQ',
    [Parameter(Mandatory=$false)][String] $Bill_To = 'I100.35000.07.01.00',
    [Parameter(Mandatory=$false)][String] $Project = 'B0003 (PPNL)',
    [Parameter(Mandatory=$false)][String] $Service_Level = 'Sandpit'
  )
  
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  Write-Verbose -Message ('SOL0012-Region: ' + $Region)
  Write-Verbose -Message ('SOL0012-Environment: ' + $Environment) 
  Write-Verbose -Message ('SOL0012-Name: ' + $NameIndividual)
  Write-Verbose -Message ('SOL0012-RgName: ' + $RgName)
  Write-Verbose -Message ('SOL0012-Administrator: ' + $Administrator) 
  Write-Verbose -Message ('SOL0012-WorkSpaceId: ' + $WorkSpaceId) 
  Write-Verbose -Message ('SOL0012-BackupRequired: ' + $BackupRequired)
  Write-Verbose -Message ('SOL0012-Allocation: ' + $Allocation) 
  Write-Verbose -Message ('SOL0012-Allocation_Group: ' + $Allocation_Group)
  Write-Verbose -Message ('SOL0012-Bill_To: ' + $Bill_To) 
  Write-Verbose -Message ('SOL0012-Project: ' + $Project)
  Write-Verbose -Message ('SOL0012-Service_Level: ' + $Service_Level)
  
      
  ###############################################################################################################################################################
  #
  # Create attributes
  #
  ###############################################################################################################################################################
  $StorageAccountName = 'felwusprdblog01s'                                                                                                                         # Used for backup
  $SqlServerAdminLocal = Get-AutomationPSCredential -Name 'CRE-AUTO-SqlServerAdminLocal'
  $SqlServerAdminAdName = 'Felix Central DBA'

  
  $RegionShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Region) 
    {   
      'West US'        {'wus'} 
      'West EU'        {'weu'} 
    }
  }
  Write-Verbose -Message ('SOL0012-RegionShortName: ' + $RegionShortName)
  
  $EnvironmentShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Environment) 
    {   
      'Production'          {'pr'} 
      'Development'         {'de'} 
      'Test'                {'te'}
    }
  }
  Write-Verbose -Message ('SOL0012-EnvironmentShortName: ' + $EnvironmentShortName)

  
  ###############################################################################################################################################################
  #
  # Create names for SQL Server and SQL Database
  #
  ###############################################################################################################################################################
  # SQL Server name
  if ($SqlServerName.Length -eq 0)                                                                                                                               # Use existing SQL Server if name provided
  {
    $SqlServerName = $RegionShortName + '-' + $EnvironmentShortName + '-' + 'sqs' + '-' + $SqlServerNameIndividual
    $SqlServerExisting = Get-AzureRmResource `
    | Where-Object {$_.ResourceType -eq 'Microsoft.Sql/servers' -and $_.Name -like "$SqlServerName*"} `
    | Sort-Object Name -Descending | Select-Object -First $True
    if ($SqlServerExisting.Count -gt 0)                                                                                                                          # Skip if first SQL Server with this name
    {
      Write-Verbose -Message ('SOL0012-SqlServerHighestCounter: ' + $SqlServerExisting.Name)

      $Counter = 1 + ($SqlServerExisting.Name.SubString(($SqlServerExisting.Name).Length-2,2))                                                                   # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $SqlServerName = $SqlServerName + '-' + $Counter1                                                                                                                # Compile name
    }
    else
    {
      $SqlServerName = $SqlServerName + '-' + '01'                                                                                                                     # Compile name for first SQL Server with this name
    }
  }
  Write-Verbose -Message ('SOL0012-SqlServerName: ' + $SqlServerName)  

  # SQL Database name
  $SqlDatabaseName = $RegionShortName + '-' + $EnvironmentShortName + '-' + 'sdb' + '-' + $SqlServerNameIndividual + $SqlServerName.Split('-')[4] + '-' + $SqlDbNameIndividual
  Write-Verbose -Message ('SOL0012-SqlDatabaseName: ' + $SqlDatabaseName) 
  
  ###############################################################################################################################################################
  #
  # Create new SQL Server if not already existing
  #
  ###############################################################################################################################################################
  try
  {
    $SqlServer = Get-AzureRmSqlServer -ResourceGroupName $RgName -ServerName $SqlServerName -ErrorAction Stop
    Write-Verbose -Message ('SOL0012-SqlServerExisting: ' + ($SqlServer | Out-String))
  }
  catch
  {
    Write-Verbose -Message ('SOL0012-SqlServerNotFound: Will create a new instance')
    try
    {
      $SqlServer = New-AzureRmSqlServer -Name $SqlServerName -ResourceGroupName $RgName -Location $Region -SqlAdministratorCredentials $SqlServerAdminLocal        
      Write-Verbose -Message ('SOL0012-SqlServerCreated: ' + ($SqlServer | Out-String))    
    }
    catch
    {
      Write-Error -Message ('SOL0012-SqlServerNotCreated: ' + $ReturnCode) 
      Return
    }
  }
  

  ###############################################################################################################################################################
  #
  # Add central DBA AD Group as Owner - this is for access to the Azure resource
  #
  ###############################################################################################################################################################
  $SqlServerAdminAd = Get-AzureRmADGroup -SearchString $SqlServerAdminAdName
  $Result = New-AzureRmRoleAssignment -ObjectId $SqlServerAdminAd.Id  -RoleDefinitionName Owner `
                                      -Scope (Get-AzureRmResource -ResourceName $SqlServerName -ResourceGroupName $RgName).ResourceId
  
  
  ###############################################################################################################################################################
  #
  # Configure the central DBA AD Group as admin (in addition to above local admin) - this is for access via tools such as SSMS (SQL Server Management Studio)
  #
  ###############################################################################################################################################################
  try
  {
    $Result = Set-AzureRmSqlServerActiveDirectoryAdministrator -DisplayName $SqlServerAdminAdName -ResourceGroupName $RgName -ServerName $SqlServerName
    Write-Verbose -Message ('SOL0012-SqlServerAdAdminCreated: ' + ($Result | Out-String))
  }
  catch
  {
    Write-Error -Message ('SOL0012-SqlServerAdAdminNotCreated: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

  
  ###############################################################################################################################################################
  #
  # Configure firewall on SQL Server
  #
  ###############################################################################################################################################################
  $Result = New-AzureRmSqlServerFirewallRule -EndIpAddress $FirewallEndIpAddress -FirewallRuleName DefaultFirewall -ResourceGroupName $RgName `
                                             -ServerName $SqlServerName -StartIpAddress $FirewallStartIpAddress


  ###############################################################################################################################################################
  #
  # Enable and configure auditing ??? left comment on how to get do SA in different subscription: https://docs.microsoft.com/en-us/azure/sql-database/scripts/sql-database-auditing-and-threat-detection-powershell?toc=%2fpowershell%2fmodule%2ftoc.json
  #
  ###############################################################################################################################################################
  InlineScript
  {
    $StorageAccountName = $Using:StorageAccountName
    $RgName = $Using:RgName
    $SqlServerName = $Using:SqlServerName

    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
    $AzureAccount = Add-AzureRmAccount -Credential $AzureAutomationCredential -SubscriptionName 'Production-pr'    
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName} 
    $StorageAccountKey = Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccountName
  
    $AzureAccount = Add-AzureRmAccount -Credential $AzureAutomationCredential -SubscriptionName 'Test-te'

    try
    {
      $Result = Set-AzureRmSqlServerAuditing -ResourceGroupName $RgName -ServerName $SqlServerName -State Enabled -RetentionInDays 10 `
                                             -StorageAccountName $StorageAccountName -StorageKeyType Primary
      Write-Verbose -Message ('SOL0012-AuditingConfigured: ' + ($Result | Out-String))
    }
    catch
    {
      Write-Error -Message ('SOL0012-AuditingNotConfigured: ' + $ReturnCode) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }      
  }
 
  
  ###############################################################################################################################################################
  #
  # Write tags to SQL Server
  #
  ###############################################################################################################################################################
  $Tags = @{Allocation_Group = $Allocation_Group; Bill_To = $Bill_To; Project = $Project; Service_Level = $Service_Level; Owner = $ServiceRequester}
  Write-Verbose -Message ('SOL0012-TagsToWrite: ' + ($Tags | Out-String))
  
  try
  {
    $Result = Set-AzureRmSqlServer -Name $SqlServerName -ResourceGroupName $RgName -Tag $Tags
    Write-Verbose -Message ('SOL0012-TagsWritten: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0012-TagsNotWritten: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

  
  ###############################################################################################################################################################
  #
  # Create new SQL Database if not already existing
  #
  ###############################################################################################################################################################
  try
  {
    $SqlDatabase = New-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName `
                                          -RequestedServiceObjectiveName Basic -ErrorAction Stop
    Write-Verbose -Message ('SOL0012-SqlDatabaseCreated: ' + ($SqlDatabase | Out-String))
  }
  catch
  {
    Write-Error -Message ('SOL0012-SqlDatabaseNotCreated: ' + $ReturnCode) 
    Return
  }
  

  ###############################################################################################################################################################
  #
  # Enable and configure auditing ??? see above
  #
  ###############################################################################################################################################################

 
  
  ###############################################################################################################################################################
  #
  # Write tags to SQL Database
  #
  ###############################################################################################################################################################
  $Tags = @{Allocation_Group = $Allocation_Group; Bill_To = $Bill_To; Project = $Project; Service_Level = $Service_Level; Owner = $ServiceRequester}
  Write-Verbose -Message ('SOL0012-TagsToWrite: ' + ($Tags | Out-String))
  
  try
  {
    $Result = Set-AzureRmSqlDatabase -Name $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName -Tag $Tags
    Write-Verbose -Message ('SOL0012-TagsWritten: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0012-TagsNotWritten: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

 
  ###############################################################################################################################################################
  #
  # Connect the SQL Database to an OMS workspace
  #
  ###############################################################################################################################################################
  try
  {
    $Result = Set-AzureRmDiagnosticSetting -ResourceId (Get-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName).ResourceId `
                                           -WorkspaceId $WorkspaceId -Enabled $True
    Write-Verbose -Message ('SOL0012-ConnectedToWorkspace: ' + ($Result | Out-String))
  }
  catch
  {
    Write-Error -Message ('SOL0012-NotConnectedToWorkspace: ' + $ReturnCode) 
  }
}