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
    $Result = Import-Module Az.Storage, Az.OperationalInsights, Az.Resources, Az.Storage                                                                         # This avoids loading the ADAL libraries
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
    $WorkspaceCoreName = Get-AutomationVariable -Name VAR-AUTO-WorkspaceBillingName
    $WorkspaceCore = Get-AzOperationalInsightsWorkspace | Where-Object {$_.Name -eq $WorkspaceCoreName}
    $WorkspaceCoreKey = (Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $WorkspaceCore.ResourceGroupName -Name $WorkspaceCore.Name).PrimarySharedKey
    $WorkspaceCoreId = $WorkspaceCore.CustomerId

    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName -Verbose:$false
    $StorageAccount = Get-AzResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey


    ###############################################################################################################################################################
    #
    # Get data using the saved query
    #
    ###############################################################################################################################################################
    $SavedSearches = (Get-AzOperationalInsightsSavedSearch -WorkspaceName $WorkspaceCoreName -ResourceGroupName $WorkspaceCore.ResourceGroupName).Value     
    $SavedSearch = $SavedSearches | Where-Object {$_.Properties.DisplayName -eq $SearchName}

    # This would be better using Get-AzOperationalInsightsSavedSearchResults but is not supported with the now Log Analytics query language
    $Results = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceCoreId -Query $SavedSearch.Properties.Query


    #############################################################################################################################################################
    #
    # Export as csv, upload fileshare and cleanup
    #
    #############################################################################################################################################################
    $Results.Results | Export-Csv D:\$SearchName.csv -noType -Force
    $Result = Set-AzStorageFileContent -ShareName reportexport -Source "D:\$SearchName.csv" -Force -Context $StorageContext
    $Result = Remove-Item D:\$SearchName.csv

  }
}

