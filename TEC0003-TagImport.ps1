###############################################################################################################################################################
# Exporting tags from an Excel document. This will overwrite all existing tags. 
#
# Error Handling: There is no error handling available in this pattern. 
# 
# Output:         None
#
# Requirements:   This requires an Excel document with a structure as created by T0002
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0003-TagImport
{
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  InlineScript
  {
    # Map drive to save Tags in Excel
    $StorageAccountName = Get-AutomationVariable -Name 'VAR-AUTO-StorageAccountName' -Verbose:$false
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageAccountKey = ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$StorageAccountName", $StorageAccountKey
    New-PSDrive -Name T -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\tagexport" -Credential $Credential -Persist
    
    # Read tags from Excel and write to Azure
    $Excel = new-object -com excel.application
    $Workbook = $Excel.workbooks.open('T:\Tags.xls')
    $Sheet = $Workbook.Sheets.Item(1)

    $RowNumber = 2
    do
    {
      # Get entries for one resource - essentially a data row in the table with the header row
      $ColumnNumber = 1
      $TagsExcel = @{}
      do
      {
        # Name (row/column)
        $Name = $Sheet.Cells.Item(1,$ColumnNumber).Value2
        if ($Name.Length -eq 0) {break} 

        # Value (row/column)
        $Value = $Sheet.Cells.Item($RowNumber,$ColumnNumber).Value2

        # Add Name/Value pair to hash table - but only if there is a value in the Tag   
        if ($Value -ne $null)
        {
          $TagsExcel.Add($Name, $Value)
        }
        $ColumnNumber++      
      }
      while ($Name.Length -gt 0)

      if ($TagsExcel.KeyName.Length -eq 0) {break}
      $TagsExcel

      #$TagsNew = @{}
      #$TagsExcel | Foreach-Object {$TagsNew[$_.Name] = $_.Value }
  
      $TagsNew = $TagsExcel.Clone()
      $TagsNew.Remove('KeyName')
      $TagsNew.Remove('KeyType')
      $TagsNew.Remove('KeyRgName')
      if ($TagsExcel.KeyType -eq 'ResourceGroup')
      {
        Set-AzureRmResourceGroup -Name $TagsExcel.KeyRgName -Tag $TagsNew
      }
      else
      {
        Set-AzureRmResource -Name $TagsExcel.KeyName -ResourceGroupName $TagsExcel.KeyRgName -ResourceType $TagsExcel.KeyType -Tag $TagsNew -Force
      }
      $RowNumber++
    }
    while ($TagsExcel.KeyName.Length -gt 0)

    $Excel.Workbooks.Close()
  }
}
