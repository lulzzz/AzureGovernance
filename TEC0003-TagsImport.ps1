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
workflow TEC0003-TagsImport
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
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUTNrI8sIU222alcR0msEZkl1G
# m/CgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKEpmzVUelYFV
# eq3HjY0DBXszl6IwDQYJKoZIhvcNAQEBBQAEggEAs0ppXFifNcLOCPXRiWN3WKHI
# UKrJGM/ab2YQMFx7eefF4lnqNFLC3a+yvg254PEa8YK6UGA/x4sfodKH2zX7wZJ0
# 0z4ZGtvX1w+r4S6tltRi3lsnLzf4B1lqwns6dOGE8G75BSaTYd4P2ZZbjf72976K
# vEZaetjuvUyLHtjQbU5HTlp44/3/qHRNL1fZ1VLDW6cohfZeYUCwajA3t71WjqzI
# FFydD9Ktr4eq5cwtKdDBtHx1xlf3HRuaxWTSxl+QlNb5MVyMYuKJo7hxMruaopLf
# +U6/RzvulhiPhCN7FNUNtLHyPKgDGTZp5MSsVW9tMv5OclUn3rwoLnMNMDBrQQ==
# SIG # End signature block
