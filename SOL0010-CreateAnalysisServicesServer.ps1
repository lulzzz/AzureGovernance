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
workflow SOL0010-CreateAnalysisServicesServer
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ServiceRequester = 'felix.bodmer@felix.bodmer.name',
    [Parameter(Mandatory=$false)][String] $Region = 'West US',
    [Parameter(Mandatory=$false)][String] $Environment = 'Test',
    [Parameter(Mandatory=$false)][String] $NameIndividual = 'analysissvc',
    [Parameter(Mandatory=$false)][String] $RgName = 'wus-te-rg-data-01',
    [Parameter(Mandatory=$false)][String] $AdminAnalysisServices = 'felix.bodmer@felix.bodmer.name, felix.bodmer@outlook.com',                                  # For access via e.g. SSMS
    [Parameter(Mandatory=$false)][String] $WorkSpaceId = '/subscriptions/ae747229-5897-4d01-93bb-284e69893c47/resourceGroups/wus-pr-rg-dba-01/providers/Microsoft.OperationalInsights/workspaces/felwusprdba01',
    [Parameter(Mandatory=$false)][String] $BackupRequired = 'No',
    [Parameter(Mandatory=$false)][String] $Allocation = 'Business',
    [Parameter(Mandatory=$false)][String] $Allocation_Group = 'DIA_HQ',
    [Parameter(Mandatory=$false)][String] $Bill_To = 'I100.35000.07.01.00',
    [Parameter(Mandatory=$false)][String] $Project = 'B0003 (PPNL)',
    [Parameter(Mandatory=$false)][String] $Service_Level = 'Sandpit'
  )
  
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  Write-Verbose -Message ('SOL0010-Region: ' + $Region)
  Write-Verbose -Message ('SOL0010-Environment: ' + $Environment) 
  Write-Verbose -Message ('SOL0010-Name: ' + $NameIndividual)
  Write-Verbose -Message ('SOL0010-RgName: ' + $RgName)
  Write-Verbose -Message ('SOL0010-Administrator: ' + $Administrator) 
  Write-Verbose -Message ('SOL0010-WorkSpaceId: ' + $WorkSpaceId) 
  Write-Verbose -Message ('SOL0010-BackupRequired: ' + $BackupRequired)
  Write-Verbose -Message ('SOL0010-Allocation: ' + $Allocation) 
  Write-Verbose -Message ('SOL0010-Allocation_Group: ' + $Allocation_Group)
  Write-Verbose -Message ('SOL0010-Bill_To: ' + $Bill_To) 
  Write-Verbose -Message ('SOL0010-Project: ' + $Project)
  Write-Verbose -Message ('SOL0010-Service_Level: ' + $Service_Level)
  
      
  ###############################################################################################################################################################
  #
  # Create attributes
  #
  ###############################################################################################################################################################
  $StorageAccountName = 'felwustediag01s'                                                                                                                         # Used for backup
  $AdminAzure = 'Felix Central DBA'                                                                                                                               # For access on Azure level
  
  $RegionShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Region) 
    {   
      'West US'        {'wus'} 
      'West EU'        {'weu'} 
    }
  }
  Write-Verbose -Message ('SOL0010-RegionShortName: ' + $RegionShortName)
  
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
  Write-Verbose -Message ('SOL0010-EnvironmentShortName: ' + $EnvironmentShortName)

  
  ###############################################################################################################################################################
  #
  # Create Analysis Services server name
  #
  ###############################################################################################################################################################
  $AnalysisServicesServerName = $RegionShortName + $EnvironmentShortName + 'aas' + $NameIndividual
  $AnalysisServicesServerExisting = Get-AzureRmResource `
                                    | Where-Object {$_.ResourceType -eq 'Microsoft.AnalysisServices/servers' -and $_.Name -like "$AnalysisServicesServerName*"} `
                                    | Sort-Object Name -Descending | Select-Object -First $True
  if ($AnalysisServicesServerExisting.Count -gt 0)                                                                                                                 # Skip if first AAS with this name
  {
    Write-Verbose -Message ('SOL0010-AnalysisServicesServerHighestCounter: ' + $AnalysisServicesServerExisting.Name)

    $Counter = 1 + ($AnalysisServicesServerExisting.Name.SubString(($AnalysisServicesServerExisting.Name).Length-2,2))                                             # Get the last two digits of the name and add one
    $Counter1 = $Counter.ToString('00')                                                                                                                            # Convert to string to get leading '0'
    $AnalysisServicesServerName = $AnalysisServicesServerName + $Counter1                                                                                          # Compile name
  }
  else
  {
    $AnalysisServicesServerName = $AnalysisServicesServerName + '01'                                                                                               # Compile name for first AAS with this name
  }
  Write-Verbose -Message ('SOL0010-AnalysisServicesServerName: ' + $AnalysisServicesServerName)  
  
  
  ###############################################################################################################################################################
  #
  # Create new Analysis Services server and verify that it exists
  #
  ###############################################################################################################################################################
  $AnalysisServicesServerId = (New-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName -Location $Region -Sku D1).Id        # Sku always D1
  try
  {
    $Result = Test-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName
    Write-Verbose -Message ('SOL0010-AnalysisServicesServerCreated: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0010-AnalysisServicesServerNotCreated: ' + $ReturnCode) 
    Return
  }
  

  ###############################################################################################################################################################
  #
  # Add central DBA AD Group as Owner - this is for access to the Azure resource
  #
  ###############################################################################################################################################################
  $AdminAzure = Get-AzureRmADGroup -SearchString $AdminAzure
  New-AzureRmRoleAssignment -ObjectId $AdminAzure.Id  -RoleDefinitionName Owner -Scope  $AnalysisServicesServerId
    

  ###############################################################################################################################################################
  #
  # Configure the Admin users for the Analysis Services server - this is for access via tools such as SSMS (SQL Server Management Studio)
  #
  ###############################################################################################################################################################
  try
  {
    $Result = Set-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName -Administrator $AdminAnalysisServices
    Write-Verbose -Message ('SOL0010-AnalysisServicesServerAdminCreated: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0010-AnalysisServicesServerAdminNotCreated: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

  
  ###############################################################################################################################################################
  #
  # Firewall ??? REST interface is currently being implemented
  #
  ###############################################################################################################################################################


  ###############################################################################################################################################################
  #
  # Create on-premises gateway - out of scope in this verson
  #
  ###############################################################################################################################################################


  ###############################################################################################################################################################
  #
  # Create container and configure backup - optional ??? not working added a question to doku site
  #
  ###############################################################################################################################################################
  if ($BackupRequired -eq 'Yes')
  {
    InlineScript
    {
      $StorageAccountName = $Using:StorageAccountName
      $RgName = $Using:RgName
      $AnalysisServicesServerName = $Using:AnalysisServicesServerName
      $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName} 
      $StorageAccountKey = Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccountName
      $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey.Value[0] 
      $StorageContainer = New-AzureStorageContainer -Name $AnalysisServicesServerName -Context $StorageContext
  
      try
      {
        $Result = Set-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName `
        -BackupBlobContainerUri $StorageContainer.CloudBlobContainer.Uri.AbsoluteUri
        Write-Verbose -Message ('SOL0010-BackupConfigured: ' + $Result | Out-String)
      }
      catch
      {
        Write-Error -Message ('SOL0010-BackupConfigured: ' + $ReturnCode) 
        Suspend-Workflow
        TEC0005-SetAzureContext
      }      
    }
  }
 
  
  ###############################################################################################################################################################
  #
  # Write tags
  #
  ###############################################################################################################################################################
  $Tags = @{Allocation_Group = $Allocation_Group; Bill_To = $Bill_To; Project = $Project; Service_Level = $Service_Level; Owner = $ServiceRequester}
  Write-Verbose -Message ('SOL0010-TagsToWrite: ' + ($Tags | Out-String))
  
  try
  {
    $Result = Set-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName -Tag $Tags
    Write-Verbose -Message ('SOL0010-TagsWritten: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0010-TagsNotWritten: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

  
  ###############################################################################################################################################################
  #
  # Connect the Analysis Services server to an OMS workspace
  #
  ###############################################################################################################################################################
  try
  {
    $Result = Set-AzureRmDiagnosticSetting -ResourceId $AnalysisServicesServerId -WorkspaceId $WorkspaceId -Enabled $True
    Write-Verbose -Message ('SOL0010-ConnectedToWorkspace: ' + ($Result | Out-String))
  }
  catch
  {
    Write-Error -Message ('SOL0010-NotConnectedToWorkspace: ' + $ReturnCode) 
  }
}