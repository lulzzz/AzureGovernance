###############################################################################################################################################################
# Exporting tags to an Excel document. 
#
# Error Handling: There is no error handling available in this pattern. 
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
workflow TEC0002-TagsExport
{
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
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
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkth4S/xq2upgQbF5kImPszhZ
# wnOgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUPmpfZnGQ71OS
# o4Po+W1YCW2SomMwDQYJKoZIhvcNAQEBBQAEggEAXZbSW08xVJ5eOfRM1qAz4ePY
# IpZEF3z6lueTFamZa3qHkV7N379ATk+w7imHfbiuEci9KFBUYeAVWci09o2zvtq2
# PPh7LLStbLc4ugAdBw7qdJF/JlCH4qJRPlcmFJiZI2wjNmdg7nOgt8+iuvC70iN3
# y03oWT0kxId2p4vALSdpslGKkqp5vw4T1Io1Oia0/9OK0iQKihBVMkWT2CS1YNC5
# Pi2mzUAtnqPcc1/Q3tJeX6A8ScTTo71S65fOfZ+XSSIwz8ZOLCRYiyKejerPNf8/
# HFnOx7aOxiWcw2fZ6usr4EHaz57ueBUI5lJqJKUOy7bY9NdtggJjFP4X9tCgmQ==
# SIG # End signature block
