###############################################################################################################################################################
# Creates a new instance of a SQL Database or SQL Datawarehouse in a new or existing SQL Server. 
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
###############################################################################################################################################################
workflow SOL0200-DatabaseAzureSqlServerNew
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ServiceRequester = 'Felix.Bodmer@RocheGroupTest.onMicrosoft.com',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = '0005',
    [Parameter(Mandatory=$false)][String] $Region = 'West Europe',
    [Parameter(Mandatory=$false)][String] $Allocation = 'Shared',
    [Parameter(Mandatory=$false)][String] $Allocation_Group = 'GIS',
    [Parameter(Mandatory=$false)][String] $Wbs = 'I100.33040.02.56',
    [Parameter(Mandatory=$false)][String] $Project = 'S0005',
    [Parameter(Mandatory=$false)][String] $Service_Level = 'SAND',
    [Parameter(Mandatory=$false)][String] $PowerOffWeekend = 'Yes',
    [Parameter(Mandatory=$false)][String] $PowerOffNight = 'Yes',
    [Parameter(Mandatory=$false)][String] $TimeZone = 'UTC+01:00',
    [Parameter(Mandatory=$false)][String] $Type = 'DWH',
    [Parameter(Mandatory=$false)][String] $RgName = 'weu-0005-rsg-refdata-01',
    [Parameter(Mandatory=$false)][String] $SqlServerName = 'weu-0005-sqs-ref-01',                                                                                                   # Enter if deployment to existing SQL Server
    [Parameter(Mandatory=$false)][String] $SqlServerNameIndividual = 'ref',
    [Parameter(Mandatory=$false)][String] $SqlDbNameIndividual = 'dwh',
    [Parameter(Mandatory=$false)][String] $FirewallStartIpAddress = '213.55.184.213',
    [Parameter(Mandatory=$false)][String] $FirewallEndIpAddress = '213.55.184.213',
    [Parameter(Mandatory=$false)][String] $WorkSpaceId = '/subscriptions/245f98ee-7b91-415b-8edf-fd572af56252/resourceGroups/weu-0005-rsg-refomsdba-01/providers/Microsoft.OperationalInsights/workspaces/rocweu0005refdba01'
  )
  
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  Write-Verbose -Message ('SOL0012-ServiceRequester: ' + $ServiceRequester)
  Write-Verbose -Message ('SOL0012-SubscriptionCode: ' + $SubscriptionCode)
  Write-Verbose -Message ('SOL0012-Region: ' + $Region)
  Write-Verbose -Message ('SOL0012-Allocation: ' + $Allocation) 
  Write-Verbose -Message ('SOL0012-Allocation_Group: ' + $Allocation_Group)
  Write-Verbose -Message ('SOL0012-Wbs: ' + $Wbs) 
  Write-Verbose -Message ('SOL0012-Project: ' + $Project)
  Write-Verbose -Message ('SOL0012-Service_Level: ' + $Service_Level)
  Write-Verbose -Message ('SOL0011-PowerOffWeekend: ' + $PowerOffWeekend)
  Write-Verbose -Message ('SOL0011-PowerOffNight: ' + $PowerOffNight)
  Write-Verbose -Message ('SOL0011-TimeZone: ' + $TimeZone)
  Write-Verbose -Message ('SOL0012-Type: ' + $Type)
  Write-Verbose -Message ('SOL0012-RgName: ' + $RgName)
  Write-Verbose -Message ('SOL0012-SqlServerName: ' + $SqlServerName)  
  Write-Verbose -Message ('SOL0012-SqlServerNameIndividual: ' + $SqlServerNameIndividual)
  Write-Verbose -Message ('SOL0012-SqlDbNameIndividual: ' + $SqlDbNameIndividual)
  Write-Verbose -Message ('SOL0012-FirewallStartIpAddress: ' + $FirewallStartIpAddress)
  Write-Verbose -Message ('SOL0012-FirewallEndIpAddress: ' + $FirewallEndIpAddress)
  Write-Verbose -Message ('SOL0012-WorkSpaceId: ' + $WorkSpaceId) 
  
      
  ###############################################################################################################################################################
  #
  # Create attributes
  #
  ###############################################################################################################################################################
  $StorageAccountName = 'rocweu0005logs01s'                                                                                                                         # Used for audit data
  $SqlServerAdminLocal = Get-AutomationPSCredential -Name 'CRE-AUTO-SqlServerAdminLocal'
  $SqlServerAdminAdName = 'CentralDbaTeam'

  $RegionShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Region) 
    {   
      'West US'        {'wus'} 
      'West Europe'    {'weu'} 
    }
  }
  Write-Verbose -Message ('SOL0012-RegionShortName: ' + $RegionShortName)

  
  ###############################################################################################################################################################
  #
  # Create names for SQL Server and SQL Database
  #
  ###############################################################################################################################################################
  # SQL Server name
  if ($SqlServerName.Length -eq 0)                                                                                                                               # Use existing SQL Server if name provided
  {
    $SqlServerName = $RegionShortName + '-' + $SubscriptionCode + '-' + 'sqs' + '-' + $SqlServerNameIndividual
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
    Write-Verbose -Message ('SOL0012-SqlServerName: ' + $SqlServerName)  

  
    ###############################################################################################################################################################
    #
    # Create new SQL Server if not already existing
    #
    ###############################################################################################################################################################
    try
    {
      $SqlServer = Get-AzureRmSqlServer -ResourceGroupName $RgName -ServerName $SqlServerName -ErrorAction Stop
      Write-Error -Message ('SOL0012-SqlServerExisting: ' + ($SqlServer | Out-String))
      Return
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
        Write-Error -Message ('SOL0012-SqlServerNotCreated: ' + $Error[0]) 
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
      Write-Error -Message ('SOL0012-SqlServerAdAdminNotCreated: ' + $Error[0]) 
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
    try
    {
      $Result = Set-AzureRmSqlServerAuditing -ResourceGroupName $RgName -ServerName $SqlServerName -State Enabled -RetentionInDays 10 `
      -StorageAccountName $StorageAccountName -StorageKeyType Primary
      Write-Verbose -Message ('SOL0012-AuditingConfigured: ' + ($Result | Out-String))
    }
    catch
    {
      Write-Error -Message ('SOL0012-AuditingNotConfigured: ' + $Error[0]) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }
 
  
    ###############################################################################################################################################################
    #
    # Write tags to SQL Server - Power Off of SQL Server is not support -> tags set to n/a
    #
    ###############################################################################################################################################################
    $Tags = @{allocation = $Allocation; allocation_group = $Allocation_Group; wbs = $WBS; project = $Project; service_level = $Service_Level; `              owner = $ServiceRequester; power_off_weekend = 'n/a'; power_off_night = 'n/a'; time_zone = 'n/a'}
    Write-Verbose -Message ('SOL0012-TagsToWrite: ' + ($Tags | Out-String))
  
    try
    {
      $Result = Set-AzureRmSqlServer -Name $SqlServerName -ResourceGroupName $RgName -Tag $Tags
      Write-Verbose -Message ('SOL0012-TagsWritten: ' + $Result | Out-String)
    }
    catch
    {
      Write-Error -Message ('SOL0012-TagsNotWritten: ' + $Error[0]) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }
  }
  

  if ($Type -eq 'DWH')
  {
    ###############################################################################################################################################################
    #
    # Create new SQL Datawarehouse 
    #
    ###############################################################################################################################################################
    # SQL Datawarehouse name
    $SqlDatabaseName = $RegionShortName + '-' + $SubscriptionCode + '-' + 'sdw' + '-' + $SqlServerNameIndividual + $SqlServerName.Split('-')[4] + '-' + `
    $SqlDbNameIndividual
    Write-Verbose -Message ('SOL0012-SqlDatabaseName: ' + $SqlDatabaseName) 

    try
    {
      $SqlDatabase = New-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName `
      -RequestedServiceObjectiveName DW100 -Edition DataWarehouse -ErrorAction Stop
      Write-Verbose -Message ('SOL0012-SqlDatabaseCreated: ' + ($SqlDatabase | Out-String))
    }
    catch
    {
      Write-Error -Message ('SOL0012-SqlDatabaseNotCreated: ' + $Error[0]) 
      Return
    }  


    ###############################################################################################################################################################
    #
    # Write tags to SQL Datawarehouse - Power Off of SQL Datawarehouse is not support -> tags set to n/a
    #
    ###############################################################################################################################################################
    $Tags = @{allocation = $Allocation; allocation_group = $Allocation_Group; wbs = $WBS; project = $Project; service_level = $Service_Level; `              owner = $ServiceRequester; power_off_weekend = 'n/a'; power_off_night = 'n/a'; time_zone = 'n/a'}
    Write-Verbose -Message ('SOL0012-TagsToWrite: ' + ($Tags | Out-String))
  
    try
    {
      $Result = Set-AzureRmSqlDatabase -Name $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName -Tag $Tags
      Write-Verbose -Message ('SOL0012-TagsWritten: ' + $Result | Out-String)
    }
    catch
    {
      Write-Error -Message ('SOL0012-TagsNotWritten: ' + $Error[0]) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }
  }
  else
  {
    ###############################################################################################################################################################
    #
    # Create new SQL Database 
    #
    ###############################################################################################################################################################
    # SQL Database name
    $SqlDatabaseName = $RegionShortName + '-' + $SubscriptionCode + '-' + 'sdb' + '-' + $SqlServerNameIndividual + $SqlServerName.Split('-')[4] + '-' + `
                       $SqlDbNameIndividual
    Write-Verbose -Message ('SOL0012-SqlDatabaseName: ' + $SqlDatabaseName) 

    try
    {
      $SqlDatabase = New-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName `
      -RequestedServiceObjectiveName Basic -ErrorAction Stop
      Write-Verbose -Message ('SOL0012-SqlDatabaseCreated: ' + ($SqlDatabase | Out-String))
    }
    catch
    {
      Write-Error -Message ('SOL0012-SqlDatabaseNotCreated: ' + $Error[0]) 
      Return
    }


    ###############################################################################################################################################################
    #
    # Write tags to SQL Database
    #
    ###############################################################################################################################################################
    $Tags = @{allocation = $Allocation; allocation_group = $Allocation_Group; wbs = $WBS; project = $Project; service_level = $Service_Level; `              owner = $ServiceRequester; power_off_weekend = $PowerOffWeekend; power_off_night = $PowerOffNight; time_zone = $TimeZone}
    Write-Verbose -Message ('SOL0012-TagsToWrite: ' + ($Tags | Out-String))
  
    try
    {
      $Result = Set-AzureRmSqlDatabase -Name $SqlDatabaseName -ResourceGroupName $RgName -ServerName $SqlServerName -Tag $Tags
      Write-Verbose -Message ('SOL0012-TagsWritten: ' + $Result | Out-String)
    }
    catch
    {
      Write-Error -Message ('SOL0012-TagsNotWritten: ' + $Error[0]) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }    
  }

 
  ###############################################################################################################################################################
  #
  # Connect the SQL Database/Datawarehouse to an OMS workspace
  #
  ###############################################################################################################################################################
  try
  {
    $Result = Set-AzureRmDiagnosticSetting -ResourceId (Get-AzureRmSqlDatabase -DatabaseName $SqlDatabaseName -ResourceGroupName $RgName `
                                           -ServerName $SqlServerName).ResourceId -WorkspaceId $WorkspaceId -Enabled $True
    Write-Verbose -Message ('SOL0012-ConnectedToWorkspace: ' + ($Result | Out-String))
  }
  catch
  {
    Write-Error -Message ('SOL0012-NotConnectedToWorkspace: ' + $Error[0]) 
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJVT8n4aw4KJa4BLsfN24M7J2
# dkCgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
# AQUFADApMScwJQYDVQQDDB5yb2NoZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20w
# HhcNMTgwNzMxMDYyODI1WhcNMTkwNzMxMDY0ODI1WjApMScwJQYDVQQDDB5yb2No
# ZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDM1mh7YGuat1ZZq9rPnnbpP2U88qpR82M75699r1TG3Ch+v6rH
# AgDMT5d3nwiyANo968M0k3w4/B8NrG+8pe8yWM7jsKv+a8VQSgig/OiRxMmP6wOO
# qVMq52uvbPCH+Ol1uJGhgUNytZDjKxkdYW/fnd8Rnnb6GWTzFWeHsm8ugk3Uiieh
# yCL66BPzmwtNX6r4Xg+NIn5U6YNBa5+jO8v67C7YdGEBkGcyDAugSfPF1qFBRpXx
# 0gTEZd5n51TkgI1CwUL4um0Wm/ntsuEdunEypgdIhtKZu8PebHsUQpZOcOg/tPu2
# y7k+gu0PT4Mg6XiG4dMdlrgpaf/yxA9dChrpAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUUFHukpelHlbkJGU5
# +MQ1XiqrD4wwDQYJKoZIhvcNAQEFBQADggEBAERlwzGl9ufvTi1YM5cCS+s+LFvL
# 9VUkBuRKmzHaH3EqpzzRWT7apISK85PbNgP09poSVwUQZ66gV+4CcTU2EDLh86k1
# noysDZushpCVSXTStBMVtgWAz2tA96ime++3QLI0k8+bod/F65eRBedPUS5LCEbf
# bmVQAtwMRXDWdjUH3jSs2F1Pep5mcQfsZZ8uCj5P6a+dMKxLVkYmg9MoXXJqNnZM
# ANVzt5NI/ErXYOFIbPq80o/EjkfEzesB4pnDH8RdvvFHljUetFgUw0t01ZQ21/iU
# QvxWOAfVkUaLOIh0rUJNh8Xfz0vmAgWtmtRXepicK9iqSrbule5EWdMmQPwxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHnJvY2hlZ3JvdXB0ZXN0Lm9ubWljcm9zb2Z0
# LmNvbQIQVIJucZNUEZlNFZMEf+jSajAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUoYKkj5xB/4f2
# 7c4Bubyc5RMws80wDQYJKoZIhvcNAQEBBQAEggEAx8hXqFPr74X9B9JP0r/ef8EE
# My8orjMHQcqeZt62VRhnDykvEvPbS/BpyNy4eR+gFngTbnMkTGGAhukVVS/9y0wM
# hnRKysDncaCRyO0mRNHawEX8utNMGUFArv/pYL7vSAfRmqXdttrakMslK4dtlcbF
# UNuSrDCbut0wnUFf88XGAFUFffGqDaFOGlN1PFch49NYCU3aVTm8Lg9SkbxNcXzh
# 64O23kYCIlatzFO62Ga5z5eNL18LfL9fpEOPRHj7SWiTfBGaZ4U9GRzeVG9gYQ/J
# SvjFvpeDOiJsUWHhoSbcVsyUkr2d5x+Wxv/qW4ld6DwU4w1nw8SabUEvIIj4qA==
# SIG # End signature block
