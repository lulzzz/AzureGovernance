###############################################################################################################################################################
# Exporting tags to an Excel document. 
#
# 
# Output:         None
#
# Requirements:   This is not working if the same tag is used with different cases, e.g. Test/test. This is because PowerShell is not case sensitive. 
#                 Some Resource Types don't allow changes on the Tags if they are not running, this might block the execution of this script.                
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0001-TagExport
{
  $VerbosePreference ='Continue'

  TEC0005-AzureContextSet
  
  InlineScript
  {
    # Create table
    $Table = New-Object System.Data.Datatable
    [void]$Table.Columns.Add('KeyName')
    [void]$Table.Columns.Add('KeyRgName')
    [void]$Table.Columns.Add('KeyType')

    # Get Tags of Resources
    $Resource = Get-AzureRmResource # | Where-Object {  $_.Name -like 'weu*' -or $_.Name -like 'roc*'}
    $Counter = $Resource.Count
    do
    {
      $Counter = $Counter - 1
      $Resource.Name[$Counter]
      $Tags = (Get-AzureRmResource -ResourceName $Resource.Name[$Counter] -ResourceGroupName $Resource.ResourceGroupName[$Counter]).Tags
      # Add columns to table
      if ($Tags.Length -ne 0)
      {
        foreach ($Tag in $Tags.Keys)
        {
          try
          {
            [void]$Table.Columns.Add($Tag)
          }
          catch
          {
            'Column already existing'
          }
        }
      }
      $Row = $Table.NewRow()
      $Row.KeyName = $Resource.Name[$Counter]
      $Row.KeyRgName = $Resource.ResourceGroupName[$Counter]
      $Row.KeyType = $Resource.ResourceType[$Counter]

      if ($Resource.Tags[$Counter] -ne $null)
      {
        foreach ($Tag in $Tags.GetEnumerator())
        {
          # Convert key/value pair to string
          $Name = $Tag.Name.ToString()
          $Value = $Tag.Value.ToString()
          Set-Variable -Name Var3 -Value $Name  
          $Row.(Get-Variable -Name Var3 -ValueOnly) = $Value
        }
      }
      $Table.Rows.Add($Row)
    } until ($Counter -eq 0)
    Write-Verbose -Message ("TEC0002-ResourceTagsRetrieved" + ($Table | Out-String))

    # Get Tags of Resource Groups
    $Resource = Get-AzureRmResourceGroup # | Where-Object {  $_.ResourceGroupName -like 'weu*' -or $_.Name -like 'roc*'}
    $Counter = $Resource.Count
    do
    {
      # Add columns to table
      $Counter = $Counter - 1
      if ($Resource[$Counter].Tags.Length -ne 0)
      {
        foreach ($Tag in $Resource.Tags[$Counter].Keys)
        {
          try
          {
            [void]$Table.Columns.Add($Tag)
          }
          catch
          {
            'Column already existing'
          }
        }
      }
      $Row = $Table.NewRow()
      $Row.KeyName = $Resource.ResourceGroupName[$Counter]
      $Row.KeyRgName = $Resource.ResourceGroupName[$Counter]
      $Row.KeyType = 'ResourceGroup'

      if ($Resource.Tags[$Counter] -ne $null)
      {
        foreach ($Tag in $Resource.Tags[$Counter].GetEnumerator())
        {
          # Convert key/value pair to string
          $Name = $Tag.Name.ToString()
          $Value = $Tag.Value.ToString()
          Set-Variable -Name Var3 -Value $Name  
          $Row.(Get-Variable -Name Var3 -ValueOnly) = $Value
        }
      }
      $Table.Rows.Add($Row)
    } until ($Counter -eq 0)
    Write-Verbose -Message ("TEC0002-ResourceGroupTagsRetrieved: " + ($Table | Out-String))
    
    # Map drive to save Tags in Excel
    $StorageAccountName = Get-AutomationVariable -Name 'VAR-AUTO-StorageAccountName' -Verbose:$false
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageAccountKey = ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$StorageAccountName", $StorageAccountKey
    $Result = New-PSDrive -Name T -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\tagexport" -Credential $Credential -Persist
    Write-Verbose -Message ('TEC0002-DriveTMapped: ' + ($Result | Out-String))
    
    $Table | export-csv T:\Tags.csv -noType 
    Remove-Item T:\Tags.xls -Force -ErrorAction SilentlyContinue
    Write-Verbose -Message ("TEC0002-CsvExported")

    # Set input and output path
    $inputCSV = 'T:\Tags.csv'
    $outputXLSX = 'T:\Tags.xlsx'
    Write-Verbose '1'

    # Create a new Excel Workbook with one empty sheet
    $excel = New-Object -ComObject excel.application 
    $workbook = $excel.Workbooks.Add(1)
    Write-Verbose '2'
    $worksheet = $workbook.worksheets.Item(1)
    Write-Verbose '3'
    
    # Build the QueryTables.Add command - QueryTables does the same as when clicking "Data -> From Text" in Excel
    $TxtConnector = ('TEXT;' + $inputCSV)
    $Connector = $worksheet.QueryTables.add($TxtConnector,$worksheet.Range('A1'))
    $query = $worksheet.QueryTables.item($Connector.name)
    Write-Verbose '4'
    # Set the delimiter (, or ;) according to your regional settings
    $query.TextFileOtherDelimiter = ',' #$Excel.Application.International(5)
    Write-Verbose '5'
    # Set the format to delimited and text for every column - A trick to create an array of 2s is used with the preceding comma
    $query.TextFileParseType  = 1
    $query.TextFileColumnDataTypes = ,2 * $worksheet.Cells.Columns.Count
    $query.AdjustColumnWidth = 1
    Write-Verbose '6'
    # Execute & delete the import query
    $query.Refresh()
    Write-Verbose '7'
    $query.Delete()
    Write-Verbose '8'
    # Save & close the Workbook as XLSX. Change the output extension for Excel 2003
    $Workbook.SaveAs($outputXLSX)
    Write-Verbose '9'
    $excel.Quit()
    Write-Verbose -Message ("TEC0002-TagsExportedToExcel")
    
    # Clean up
    #Remove-Item T:\Tags.csv
    Remove-PSDrive -Name T -Force
  }
}