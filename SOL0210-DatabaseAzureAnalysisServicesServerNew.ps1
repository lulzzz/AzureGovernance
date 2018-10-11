###############################################################################################################################################################
# Creates a new instance of an Azure Analysis Service based on the input parameters.
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
workflow SOL0210-DatabaseAzureAnalysisServicesServerNew
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
    [Parameter(Mandatory=$false)][String] $NameIndividual = 'ref',
    [Parameter(Mandatory=$false)][String] $RgName = 'weu-0005-rsg-refdata-01',
    [Parameter(Mandatory=$false)][String] $AdminAnalysisServices = 'Felix.Bodmer@RocheGroupTest.onMicrosoft.com, jorge.guillen_adan@RocheGroupTest.onMicrosoft.com',                            # For access via e.g. SSMS
    [Parameter(Mandatory=$false)][String] $BackupRequired = 'No',
    [Parameter(Mandatory=$false)][String] $WorkSpaceId = '/subscriptions/245f98ee-7b91-415b-8edf-fd572af56252/resourceGroups/weu-0005-rsg-refomsdba-01/providers/Microsoft.OperationalInsights/workspaces/rocweu0005refdba01'
  )
  
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  Write-Verbose -Message ('SOL0011-ServiceRequester: ' + $ServiceRequester)
  Write-Verbose -Message ('SOL0011-SubscriptionCode: ' + $SubscriptionCode)
  Write-Verbose -Message ('SOL0011-Region: ' + $Region)
  Write-Verbose -Message ('SOL0011-Allocation: ' + $Allocation)
  Write-Verbose -Message ('SOL0011-Allocation_Group: ' + $Allocation_Group)
  Write-Verbose -Message ('SOL0011-WBS: ' + $Wbs) 
  Write-Verbose -Message ('SOL0011-Project: ' + $Project)
  Write-Verbose -Message ('SOL0011-Service_Level: ' + $Service_Level)
  Write-Verbose -Message ('SOL0011-PowerOffWeekend: ' + $PowerOffWeekend)
  Write-Verbose -Message ('SOL0011-PowerOffNight: ' + $PowerOffNight)
  Write-Verbose -Message ('SOL0011-TimeZone: ' + $TimeZone)
  Write-Verbose -Message ('SOL0011-NameIndividual: ' + $NameIndividual)  
  Write-Verbose -Message ('SOL0011-RgName: ' + $RgName) 
  Write-Verbose -Message ('SOL0011-AdminAnalysisServices: ' + $AdminAnalysisServices) 
  Write-Verbose -Message ('SOL0011-BackupRequired: ' + $BackupRequired) 
       
      
  ###############################################################################################################################################################
  #
  # Create attributes
  #
  ###############################################################################################################################################################
  $StorageAccountName = 'rocweu0005logs01s'                                                                                                                         # Used for backup                                                                                                                    # Used for backup
  $AdminAzure = 'CentralDbaTeam'                                                                                                                                    # For access on Azure level
  
  $RegionShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Region) 
    {   
      'West US'        {'wus'} 
      'West Europe'    {'weu'} 
    }
  }
  Write-Verbose -Message ('SOL0010-RegionShortName: ' + $RegionShortName)
  
  
  ###############################################################################################################################################################
  #
  # Create Analysis Services server name
  #
  ###############################################################################################################################################################
  $AnalysisServicesServerName = $RegionShortName + $SubscriptionCode + 'aas' + $NameIndividual
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
    Write-Error -Message ('SOL0010-AnalysisServicesServerNotCreated: ' + $Error[0]) 
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
    Write-Error -Message ('SOL0010-AnalysisServicesServerAdminNotCreated: ' + $Error[0]) 
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
        Write-Error -Message ('SOL0010-BackupConfigured: ' + $Error[0]) 
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
  $Tags = @{allocation = $Allocation; allocation_group = $Allocation_Group; wbs = $WBS; project = $Project; service_level = $Service_Level; `            owner = $ServiceRequester; power_off_weekend = $PowerOffWeekend; power_off_night = $PowerOffNight; time_zone = $TimeZone}
  Write-Verbose -Message ('SOL0010-TagsToWrite: ' + ($Tags | Out-String))
  
  try
  {
    $Result = Set-AzureRmAnalysisServicesServer -Name $AnalysisServicesServerName -ResourceGroupName $RgName -Tag $Tags
    Write-Verbose -Message ('SOL0010-TagsWritten: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0010-TagsNotWritten: ' + $Error[0]) 
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
    Write-Error -Message ('SOL0010-NotConnectedToWorkspace: ' + $Error[0]) 
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5iLVRdBJif/FyX/xGkRDV3qG
# FP+gggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/OHY0K/9Mvbg
# A4moaL3EBKgnz1AwDQYJKoZIhvcNAQEBBQAEggEAwAuUdYmjznnbVebMGkqvYils
# D+4HVjKZ6nYvjqmT10Pmh+HQFDu2vlu8k8j3cgLf5vZ3DpZ9GyZQQ83kkVVwX5Be
# noXC1xDM/VNVxtb5OAuSpKrcLxTHLbYQClXkcCHGMXXlgp0MuDjX9sbj37cG8N+u
# qjSeFmKi1U2pt3DGzjb1kp5WCVcf3JPgMWyIfwTppR1QUgtqrJoJDVj6h8oWLhVv
# ey6/nHDcgCxnQwxQbeB7hQwv11v/ZsZNYFyVYES1AlFbEpQsGvI4VtMnzN2c3JiZ
# 2lKBoXZzACNHZdkcC0h4awV80DFjHjeogayBnk2kY8iUjArC5R/Sp/413veZtw==
# SIG # End signature block
