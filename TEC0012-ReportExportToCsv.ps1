###############################################################################################################################################################
# Exports a Log Analytics report in the Core instance to a csv on a file share 'reportexport' in the Core Storage Account.
# 
# Output:         none
#
# Requirements:   See Import-Module in code below / File share to store CSV output
#
# Template:       TEC0012-ReportExportToCsv -SearchName $SearchName
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow TEC0012-ReportExportToCsv
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $SearchName = 'TEC0010-ExportUsageData'
  )


  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Azure.Storage, AzureRM.OperationalInsights, AzureRM.Resources, AzureRM.Storage                                                       # This avoids loading the ADAL libraries
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

 
  InlineScript
  {
    $SearchName = $Using:SearchName

    #############################################################################################################################################################
    #  
    # Parameters
    #
    #############################################################################################################################################################
    $Credentials = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser
    $WorkspaceCoreName = Get-AutomationVariable -Name VAR-AUTO-WorkspaceCoreName
    $WorkspaceCore = Get-AzureRmOperationalInsightsWorkspace | Where-Object {$_.Name -eq $WorkspaceCoreName}
    $WorkspaceCoreKey = (Get-AzureRmOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $WorkspaceCore.ResourceGroupName -Name $WorkspaceCore.Name).PrimarySharedKey
    $WorkspaceCoreId = $WorkspaceCore.CustomerId

    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName -Verbose:$false
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey


    ###############################################################################################################################################################
    #
    # Get data using the saved query
    #
    ###############################################################################################################################################################
    $SavedSearches = (Get-AzureRmOperationalInsightsSavedSearch -WorkspaceName $WorkspaceCoreName -ResourceGroupName $WorkspaceCore.ResourceGroupName).Value     
    $SavedSearch = $SavedSearches | Where-Object {$_.Properties.DisplayName -eq $SearchName}

    # This would be better using Get-AzureRmOperationalInsightsSavedSearchResults but is not supported with the now Log Analytics query language
    $Results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceCoreId -Query $SavedSearch.Properties.Query


    #############################################################################################################################################################
    #
    # Export as csv, upload fileshare and cleanup
    #
    #############################################################################################################################################################
    $Results.Results | Export-Csv D:\$SearchName.csv -noType -Force
    $Result = Set-AzureStorageFileContent -ShareName reportexport -Source "D:\$SearchName.csv" -Force -Context $StorageContext
    $Result = Remove-Item D:\$SearchName.csv

  }
}