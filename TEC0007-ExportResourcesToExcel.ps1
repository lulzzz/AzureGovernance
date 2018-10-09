###############################################################################################################################################################
# Exporting tags to an Excel document. 
#
# Error Handling: There is no error handling available in this pattern. 
# 
# Output:         None
#
# Requirements:   Ensure the delimiter is corresponds to what is configured on the system (see comment below)
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0007-ExportResourcesToExcel
{
  [OutputType([object])] 	

  param
	(
  )

  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext

  InlineScript
  {
    ###############################################################################################################################################################
    #
    # Select all resources, tags and write to table
    #
    ###############################################################################################################################################################
    # Create table
    $Table = New-Object System.Data.Datatable
    [void]$Table.Columns.Add('KeyName')
    [void]$Table.Columns.Add('KeyRgName')
    [void]$Table.Columns.Add('KeyType')

    $Resource = Get-AzureRmResource | Where-Object {
                                                      # $_.ResourceType -eq 'Microsoft.Web/sites' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Web/serverFarms' -or 
                                                      # $_.ResourceType -eq 'microsoft.storsimple/managers' -or 
                                                      $_.ResourceType -eq 'Microsoft.Storage/storageAccounts' -or 
                                                      $_.ResourceType -eq 'Microsoft.Sql/servers/databases' -or 
                                                      $_.ResourceType -eq 'Microsoft.Sql/servers' -or 
                                                      $_.ResourceType -eq 'Microsoft.RecoveryServices/vaults' -or 
                                                      # $_.ResourceType -eq 'Microsoft.OperationsManagement/solutions' -or 
                                                      # $_.ResourceType -eq 'Microsoft.OperationalInsights/workspaces' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/virtualNetworks' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/virtualNetworkGateways' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Network/routeTables' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/publicIPAddresses' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/networkSecurityGroups' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/networkInterfaces' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/localNetworkGateways' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/loadBalancers' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/connections' -or 
                                                      $_.ResourceType -eq 'Microsoft.KeyVault/vaults' -or 
                                                      # $_.ResourceType -eq 'microsoft.insights/components' -or 
                                                      # $_.ResourceType -eq 'microsoft.insights/autoscalesettings' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Insights/alertrules' -or 
                                                      # $_.ResourceType -eq 'Microsoft.DataFactory/dataFactories' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Compute/virtualMachines/extensions' -or 
                                                      $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' -or 
                                                      # $_.ResourceType -eq 'Microsoft.ClassicStorage/storageAccounts' -or 
                                                      # $_.ResourceType -eq 'Microsoft.ClassicNetwork/networkSecurityGroups' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Automation/automationAccounts/runbooks' -or 
                                                      $_.ResourceType -eq 'Microsoft.Automation/automationAccounts' 
                                                      # $_.ResourceType -eq 'Microsoft.AppService/gateways'
                                                   }
    $Counter = $Resource.Count

    do
    {
      $Counter = $Counter - 1
      Write-Verbose -Message ('TEC0007-Resource: ' + $Resource.Name[$Counter])
      $Tags = (Get-AzureRmResource -ResourceName $Resource.Name[$Counter] -ResourceGroupName $Resource.ResourceGroupName[$Counter]).Tags
      # Add columns to table
      if ($Tags.Length -ne 0)
      {
        foreach ($Tag in $Tags.Keys)
        {
          try
          {
            [void]$Table.Columns.Add($Tag)
            Write-Verbose -Message ('TEC0007-ColumnCreated: ' + $Tag)
          }
          catch
          {
            Write-Verbose -Message ('TEC0007-ColumnExisting: ' + $Tag)
          }
        }

        $Row = $Table.NewRow()
        $Row.KeyName = $Resource.Name[$Counter]
        $Row.KeyRgName = $Resource.ResourceGroupName[$Counter]
        #$C = (($Resource.ResourceType[$Counter]).Split('.')).Count
        #$Row.KeyType = (($Resource.ResourceType[$Counter]).Split('.'))[$C-1]
        $Row.KeyType = $Resource.ResourceType[$Counter]

        foreach ($Tag in $Tags.GetEnumerator())
        {
          # Convert key/value pair to string
          $Name = $Tag.Name.ToString()
          $Value = $Tag.Value.ToString()
          $Result = Set-Variable -Name Var3 -Value $Name  
          $Row.(Get-Variable -Name Var3 -ValueOnly) = $Value
        }
        $Table.Rows.Add($Row)
      }
    } until ($Counter -eq 0)


    $Table | export-csv C:\PowerBiSources\Resources.csv -noType 

    ###############################################################################################################################################################
    #
    # Write table content to Excel document
    #
    ###############################################################################################################################################################
 
    $Result = Remove-Item C:\PowerBiSources\Resources.xlsx

    ### Set input and output path
    $inputCSV = 'C:\PowerBiSources\Resources.csv'
    $outputXLSX = 'C:\PowerBiSources\Resources.xlsx'

    ### Create a new Excel Workbook with one empty sheet
    $excel = New-Object -ComObject excel.application 
    $workbook = $excel.Workbooks.Add(1)
    $Worksheet = $workbook.Worksheets.Item(1)
    $Worksheet.Name = 'Resources'

    ### Build the QueryTables.Add command
    ### QueryTables does the same as when clicking "Data » From Text" in Excel
    $TxtConnector = ('TEXT;' + $inputCSV)
    $Connector = $Worksheet.QueryTables.add($TxtConnector,$Worksheet.Range('A1'))
    $Query = $Worksheet.QueryTables.item($Connector.name)

    ### Set the delimiter (, or ;) according to your regional settings
    $Query.TextFileOtherDelimiter = ',' #$Excel.Application.International(5)

    ### Set the format to delimited and text for every column
    ### A trick to create an array of 2s is used with the preceding comma
    $Query.TextFileParseType  = 1
    $Query.TextFileColumnDataTypes = ,2 * $Worksheet.Cells.Columns.Count
    $Query.AdjustColumnWidth = 1

    # Execute & delete the import Query
    $Query.Refresh()
    $Query.Delete()

    # Save & close the Workbook as XLSX
    $Workbook | gm
    $Workbook.SaveAs($OutputXlsx)
    $Excel.Quit()

    $Result = Remove-Item C:\PowerBiSources\Resources.csv
  }
}