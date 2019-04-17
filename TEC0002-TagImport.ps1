###############################################################################################################################################################
# Imports tags from an Excel document created with TEC0001. This will overwrite all existing tags. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below / Excel installed on Hybrid Runbook Worker / 'tagexport/Tags.xls' file and share on Core Storage Account
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow TEC0002-TagImport
{
  [OutputType([object])]

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = 'te'
  )


  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Resources, Az.Storage
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet
  
  InlineScript
  {
    $SubscriptionShortName = $Using:SubscriptionShortName


    #############################################################################################################################################################
    #
    # Download the file
    #
    #############################################################################################################################################################
    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName -Verbose:$false
    $StorageAccount = Get-AzResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    Get-AzStorageFileContent -ShareName tagexport -Path Tags.xlsx -Destination D:\Tags.xlsx -Force -Context $StorageContext


    #############################################################################################################################################################
    #
    # Change to Subscription where Tags are imported
    #
    #############################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('SOL0150-AzureContext: ' + ($AzureContext | Out-String))
      
    # Read tags from Excel and write to Azure
    $Excel = New-Object -com excel.application
    $Workbook = $Excel.workbooks.open('D:\Tags.xlsx')
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
        Set-AzResourceGroup -Name $TagsExcel.KeyRgName -Tag $TagsNew
      }
      else
      {
        Set-AzResource -Name $TagsExcel.KeyName -ResourceGroupName $TagsExcel.KeyRgName -ResourceType $TagsExcel.KeyType -Tag $TagsNew -Force
      }
      $RowNumber++
    }
    while ($TagsExcel.KeyName.Length -gt 0)

    $Excel.Workbooks.Close()
    Remove-Item D:\Tags.xlsx -Force
  }
}
