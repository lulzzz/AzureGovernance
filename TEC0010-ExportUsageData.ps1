###############################################################################################################################################################
# Retrieving consumption details, formating the data and and writing to a Log Analytics instance
# 
# Output:         None
#
# Requirements:   AzureRM.profile, AzureRM.Resources, AzureRM.UsageAggregates, Microsoft.ADAL.PowerShell - this avoids loading the ADAL libraries
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow TEC0010-ExportUsageData
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $LogType = 'CostMonitoring'                                                                                            # Will be written as CostMonitoring_CL to Log Analytics
  )

  $VerbosePreference ='Continue'
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.profile, AzureRM.Resources, AzureRM.UsageAggregates
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet
  
  $Credentials = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser
  $CoreWorkspaceId = Get-AutomationVariable -Name VAR-AUTO-CoreWorkspaceId
  $CoreWorkspaceKey = Get-AutomationVariable -Name VAR-AUTO-CoreWorkspaceKey

  
  InlineScript
  {
    $LogType = $Using:LogType
    $CoreWorkspaceId = $Using:CoreWorkspaceId
    $CoreWorkspaceKey = $Using:CoreWorkspaceKey
    $Credentials = $Using:Credentials

    Write-Verbose -Message ('TEC0009-LogType: ' + $LogType)
    Write-Verbose -Message ('TEC0009-CoreWorkspaceId: ' + $CoreWorkspaceId)
    Write-Verbose -Message ('TEC0009-CoreWorkspaceKey: ' + $CoreWorkspaceKey)


    ###########################################################################################################################################################
    #
    # Get usage data
    #
    ###########################################################################################################################################################
    # Set usage parameters
    $Subscriptions = Get-AzureRmSubscription
    $StartDateTime = [string](get-date -Format yyyy) + '-' + [string](get-date -Format MM) + '-01T00:00:00+00:00'
    $CurrentHour = Get-Date
    $CurrentHour = $CurrentHour.ToUniversalTime()
    [string]$EndDateTime = [string](get-date -Format yyyy) + '-' + [string](get-date -Format MM) + '-' + [string](get-date -Format dd) + 'T' + `                 # UTC -1 hr to get latest records
                           ($CurrentHour.Hour -3).ToString("00") + ':00:00+00:00'
    Write-Verbose -Message ('TEC0009-StartDateTime: ' + $StartDateTime)
    Write-Verbose -Message ('TEC0009-EndDateTime: ' + $EndDateTime)

    # Get usage records
    foreach ($Subscription in $Subscriptions)
    {
      $Result = Connect-AzureRmAccount -Credential $Credentials -Subscription $Subscription.Name
      Write-Verbose -Message ('TEC0009-RetrieveUsageForSubscription: ' + ($Result | Out-String))
       
      # Get first 10000 records, try for 2 x 15 minutes and then abort
      $Counter = 0
      do
      {
        if ($UsageDataSet = Get-AzureRmConsumptionUsageDetail -IncludeMeterDetails -IncludeAdditionalProperties -StartDate $StartDateTime `
                                                -EndDate $EndDateTime -ErrorAction SilentlyContinue)
        {
          Break
        }
        $Counter++
        if ($Counter -le '2') 
        {
          Write-Verbose -Message ('TEC0009-DataNotYetAvailable: will retry in 15 minutes at ' + (Get-Date).AddMinutes(15))
          Start-Sleep -Seconds 900
        }
      }
      while ($Counter -le '2')

      if ($Counter -eq '2')
      {
        Write-Error -Message ('TEC0009-NoDataAvailable: Tried retrieving data for 45 minutes')
        Return
      }
      $UsageData = $UsageData + $UsageDataSet.UsageAggregations
      Write-Verbose -Message ('TEC0009-NumberOfRetrievedUsageRecords: ' + $UsageData.Count)

      # Get additional records using Continuation Token and NextLink
      do
      {
        $UsageDataSet = Get-AzureRmConsumptionUsageDetail -IncludeMeterDetails -IncludeAdditionalProperties -StartDate $StartDateTime `
                                                -EndDate $EndDateTime -ErrorAction SilentlyContinue -ContinuationToken $UsageDataSet.ContinuationToken

        $UsageData = $UsageData + $UsageDataSet.UsageAggregations
        Write-Verbose -Message ('TEC0009-NumberOfRetrievedUsageRecords: ' + $UsageData.Count)
      }
      while ($UsageDataSet.NextLink)
    }
    Write-Verbose -Message ('TEC0009-TotalNumberOfRetrievedUsageRecords: ' + $UsageData.Count)


    ###########################################################################################################################################################
    #
    # Write data to Log Analytics
    #
    ###########################################################################################################################################################
    # Variables
    $Resource = '/api/logs'
    $Json = ''
    $ContentType = 'application/json'
    $Method = 'POST'

    # Create body and wrap in an array
    foreach ($Item in $UsageData)
    {                        `
      $Json += @"
      {"ResourceGroupName":"$($Item.InstanceId.split('/')[4])", "ResourceName":"$($Item.InstanceName)", "Cost":"$($Item.PretaxCost)", "Tag":"$($Item.Tags)"},
"@
    }
        
    $Json = "[$Json]"

    # Create authorization signature
    $Rfc1123Date = [DateTime]::UtcNow.ToString('r')
    $ContentLength = $Json.Length
    $XHeaders = 'x-ms-date:' + $Rfc1123Date 
    $StringToHash = $Method + "`n" + $ContentLength + "`n" + $ContentType + "`n" + $XHeaders + "`n" + $Resource
    $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToHash)
    $KeyBytes = [Convert]::FromBase64String($CoreWorkspaceKey)
    $Sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $Sha256.Key = $KeyBytes
    $CalculatedHash = $Sha256.ComputeHash($BytesToHash)
    $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
    $Authorization = 'SharedKey {0}:{1}' -f $CoreWorkspaceId,$EncodedHash

    # Post the request
    $Uri = 'https://' + $CoreWorkspaceId + '.ods.opinsights.azure.com' + $Resource + '?api-version=2016-04-01'
    $Headers = @{'Authorization' = $Authorization;
                 'Log-Type' = $LogType;
                 'x-ms-date' = $Rfc1123Date;
                }
    $Result = Invoke-WebRequest -Uri $Uri -Method $Method -ContentType $ContentType -Headers $Headers -Body $Json -UseBasicParsing
    
    Write-Verbose -Message ('TEC0009-DataWritenToOms: End of process')  

  }  
}