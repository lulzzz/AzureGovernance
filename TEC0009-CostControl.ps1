###############################################################################################################################################################
# Compares the actual cost accumulated on a resource with the estimated cost value captured in the Tag of the Resource Group.
# The resource data is retrieved based on the $StartDateTime and $EndDateTime, for the Resource Groups current data is retrieved. This means that Resources
# in deleted Resource Groups are supplied, but not the Resource Group itself. 
# The $OfferDurableId is used to retrieve the rate cards. EA rate cards are not supported (see link below), never-the less 'MS-AZR-0017P' will be used.
# These rate cards do not include customer specific discounts but should be sufficient for a cost approximation.
# https://docs.microsoft.com/en-us/azure/billing/billing-usage-rate-card-overview#azure-resource-ratecard-api-preview
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
workflow TEC0009-CostControl
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $AdTenant = 'felix.bodmer.name',
    [Parameter(Mandatory=$false)][String] $AadApplicationId = '0dad1d52-4c4a-4a69-9ed7-13af0e9d806f',
    [Parameter(Mandatory=$false)][String] $OfferDurableId = 'MS-AZR-0017P',                                                                                      # https://azure.microsoft.com/en-us/support/legal/offer-details/, can't be retrieved by PowerShell
    [Parameter(Mandatory=$false)][String] $Currency = 'CHF',                                                                                                     # USD / CHF
    [Parameter(Mandatory=$false)][String] $Locale = 'de-CH',                                                                                                     # en-US / de-CH
    [Parameter(Mandatory=$false)][String] $RegionInfo = 'CH',                                                                                                    # US / CH
    [Parameter(Mandatory=$false)][String] $LogType = 'CostMonitoring'
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
    $Result = Import-Module AzureRM.profile, AzureRM.Resources, AzureRM.UsageAggregates, Microsoft.ADAL.PowerShell
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet
  
  $Credentials = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser
  $CoreWorkspaceId = Get-AutomationVariable -Name VAR-AUTO-CoreWorkspaceId
  $CoreWorkspaceKey = Get-AutomationVariable -Name VAR-AUTO-CoreWorkspaceKey
  
  InlineScript
  {
    $AdTenant = $Using:AdTenant
    $AadApplicationId = $Using:AadApplicationId
    $OfferDurableId = $Using:OfferDurableId
    $Currency = $Using:Currency
    $Locale = $Using:Locale
    $RegionInfo = $Using:RegionInfo
    $LogType = $Using:LogType
    $CoreWorkspaceId = $Using:CoreWorkspaceId
    $CoreWorkspaceKey = $Using:CoreWorkspaceKey
    $Credentials = $Using:Credentials

    Write-Verbose -Message ('TEC0009-AdTenant: ' + $AdTenant)
    Write-Verbose -Message ('TEC0009-AadApplicationId: ' + $AadApplicationId)
    Write-Verbose -Message ('TEC0009-OfferDurableId: ' + $OfferDurableId)
    Write-Verbose -Message ('TEC0009-Currency: ' + $Currency)
    Write-Verbose -Message ('TEC0009-Locale: ' + $Locale)
    Write-Verbose -Message ('TEC0009-RegionInfo: ' + $RegionInfo)
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
    $Granularity = 'Hourly'                                                                                                                                      # Can be Hourly or Daily
    $ShowDetails = $true
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
      $Result = Add-AzureRmAccount -Credential $Credentials -Subscription $Subscription.Name
      Write-Verbose -Message ('TEC0009-RetrieveUsageForSubscription: ' + ($Result | Out-String))
       
      # Get first 10000 records, try for 2 x 15 minutes and then abort
      $Counter = 0
      do
      {
        if ($UsageDataSet = Get-UsageAggregates -ReportedStartTime $StartDateTime `
                                                -ReportedEndTime $EndDateTime `
                                                -AggregationGranularity $Granularity `
                                                -ShowDetails $ShowDetails `
                                                -ErrorAction SilentlyContinue)
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
        $UsageDataSet = Get-UsageAggregates -ReportedStartTime $StartDateTime `
                                            -ReportedEndTime $EndDateTime `
                                            -AggregationGranularity $Granularity `
                                            -ShowDetails $ShowDetails `
                                            -ContinuationToken $UsageDataSet.ContinuationToken

        $UsageData = $UsageData + $UsageDataSet.UsageAggregations
        Write-Verbose -Message ('TEC0009-NumberOfRetrievedUsageRecords: ' + $UsageData.Count)
      }
      while ($UsageDataSet.NextLink)
    }
    Write-Verbose -Message ('TEC0009-TotalNumberOfRetrievedUsageRecords: ' + $UsageData.Count)

    # Select unique rate cards
    $RateCardsRequired = $UsageData.Properties.MeterId | Sort-Object -Unique
    Write-Verbose -Message ('TEC0009-NumberOfRequiredRateCards: ' + $RateCardsRequired.Count)


    ###########################################################################################################################################################
    #
    # Get Rate Cards
    #
    ###########################################################################################################################################################
    # Acquire token
    $AccessToken = Get-ADALAccessToken -AuthorityName $AdTenant -ClientId $AadApplicationId -ResourceId 'https://management.core.windows.net/' `
                                       -UserName $Credentials.UserName -Password $Credentials.GetNetworkCredential().password                                    # Requires password as string
 
    # Execute call to get Rate Cards - Select one of the subscriptions assume they all use the same Currency/Locale/RegionInfo ???
    $Filter = "OfferDurableId eq '$OfferDurableId' and Currency eq '$Currency' and Locale eq '$Locale' and RegionInfo eq '$RegionInfo'"
    $Subscription = Get-AzureRmSubscription | Select-Object -First 1
    $Uri = 'https://management.azure.com/subscriptions/' + $Subscription.Id + '/providers/Microsoft.Commerce/RateCard?api-version=2016-08-31-preview&$filter=' + $Filter
    $Header = @{Authorization = 'Bearer ' + $AccessToken}
    $RateCards = Invoke-RestMethod -Uri $Uri `
                                   -Method Get `
                                   -ContentType 'application/json' `
                                   -Headers $Header

    Write-Verbose -Message ('TEC0009-RateCardsRetrieved: ' + $RateCards.Meters.Count)

    # Reduce to Rate Cards to the ones that are actually used/required - for performance reasons
    $RateCardsMeters = foreach ($RateCard in $RateCards.Meters)
    {
      $RateCard | Where-Object {$RateCardsRequired -contains $RateCard.MeterID}
    }

    Write-Verbose -Message ('TEC0009-RateCardsUsed: ' + $RateCardsMeters.Count) 


    ###########################################################################################################################################################
    #
    # Combine Usage and Metrics data from rate cards into a single table
    #
    ###########################################################################################################################################################
    $Combined = foreach ($Usage in $UsageData.Properties)
    {
      if ($Usage.MeterId -ne '00000000-0000-0000-0000-000000000000'-and $Usage.MeterName -ne $null)                                                              # Discard usage records without rate card
      {
        $TagValue = (($Usage.InstanceData -split '{"Monatliche-Kosten":"')[1] -split '"')[0]
        $Uri = (($Usage.InstanceData -split '{"Microsoft.Resources":{"resourceUri":"') -split '","location"')[1]
        $ResourceGroupName = (($Usage.InstanceData -split '/')[4]).ToLower()
        $ResourceName = ((($Usage.InstanceData -split '/')[8] -split '","')[0]).ToLower()
        $Meter = ($RateCardsMeters | Where-Object {$_.MeterId -eq $Usage.MeterId} | Select-Object -Property IncludedQuantity, MeterRates, MeterId, MeterName)
  
        [PSCustomObject]@{ResourceGroupName = $ResourceGroupName; `                          ResourceName = $ResourceName; `                          UsageStartTime = $Usage.UsageStartTime; `                          UsageEndTime = $Usage.UsageEndTime; `                          UsageQuantity = $Usage.Quantity; `                          UsageUnit = $Usage.Unit; `                          MeterName = $Meter.MeterName; `
                          MeterIncludedQuantity = $Meter.IncludedQuantity; `                          MeterRates = $Meter.MeterRates; `                          Tag = $TagValue; `
                          Uri = $Uri; `                          MeterId = $Meter.MeterId; `
                          Grouping = $Uri + $Meter.MeterId; `
        }
      } 
    }
    Write-Verbose -Message ('TEC0009-CombinedUsageAndRateCardRecords: ' + $Combined.Count) 


    ###########################################################################################################################################################
    #
    # Summarize usage across all days/hours and combine with above table
    #
    ###########################################################################################################################################################
    # Summarize the Usage for each Resource/Metric touple - necessary because there is an entry for each hour
    $UsageTotals = $Combined | Sort-Object Grouping | Group-Object -Property Grouping | `
    Select-Object -Property name,@{n="UsageTotal";e={$_.group | ForEach-Object -begin {$i=0} -process {$i+=$_.UsageQuantity} -end {$i}}} 

    # Combine the first two tables
    $CombinedUsageTotals = foreach ($UsageTotal in $UsageTotals)
    {
      $Record = ($Combined | Where-Object {$_.Grouping -eq $UsageTotal.Name}) | Select-Object -First 1

      [PSCustomObject]@{ResourceGroupName = $Record.ResourceGroupName; `                        ResourceName = $Record.ResourceName; `                        UsageQuantityTotal = $UsageTotal.UsageTotal; `                        UsageUnit = $Record.UsageUnit; `                        MeterName = $Record.MeterName
                        MeterIncludedQuantity = $Record.MeterIncludedQuantity; `                        MeterRates = $Record.MeterRates; `                        Tag = $Record.Tag; `
                        Uri = $Record.Uri; `                        MeterId = $Record.MeterId; `
      }    
    }
    Write-Verbose -Message ('TEC0009-CombinedSummarizedUsageAndRateCardRecords: ' + $CombinedUsageTotals.Count) 


    ###########################################################################################################################################################
    #
    # Calculate cost in CHF and combine with above table
    #
    ###########################################################################################################################################################
    # Calculate the usage in CHF
    $CombinedUsageTotalsChf = foreach ($CombinedUsageTotal in $CombinedUsageTotals)
    {
      # Get applicable Rate Card
      $MeterRecord = $RateCardsMeters | Where-Object {$_.MeterId -eq $CombinedUsageTotal.MeterId}
  
      # Get all the Rate Card NoteProperties - the individual rates are available as NoteProperties on the object 
      $MeterRecordNps = $MeterRecord.MeterRates.PSObject.Properties.Name | Sort-Object
  
      # Determine the correct NoteProperty
      $MeterRecordNp = $MeterRecordNps[0]
      foreach ($Np in $MeterRecordNps)
      {
        if ($CombinedUsageTotal.UsageTotal -lt $Np)
        {
          break
        } 
        $MeterRecordNp = $Np
      }
      $Rate = $MeterRecord.MeterRates.$MeterRecordNp

      # Calculate Usage charged and Cost
      $UsageCharged = 
      if ($CombinedUsageTotal.UsageQuantityTotal - $CombinedUsageTotal.MeterIncludedQuantity -le 0)
      {
        0
      }      else      {      ($CombinedUsageTotal.UsageQuantityTotal - $CombinedUsageTotal.MeterIncludedQuantity)       }      $Cost = $UsageCharged * $Rate      [PSCustomObject]@{ResourceGroupName = $CombinedUsageTotal.ResourceGroupName; `                        ResourceName = $CombinedUsageTotal.ResourceName; `                        UsageQuantityTotal = $CombinedUsageTotal.UsageQuantityTotal; `                        UsageUnit = $CombinedUsageTotal.UsageUnit; `                        MeterName = $CombinedUsageTotal.MeterName
                        MeterIncludedQuantity = $CombinedUsageTotal.MeterIncludedQuantity; `                        UsageCharged = $UsageCharged; `                        MeterRates = $MeterRecord.MeterRates; `                        Rate = $Rate; `                        Cost = $Cost; `                        MeterRecordNps = $MeterRecordNps; `                        MeterRecordNp = $MeterRecordNp; `
                        Tag = $CombinedUsageTotal.Tag; `
      }
    }
    Write-Verbose -Message ('TEC0009-CombinedSummarizedUsageAndRateCardRecordsChf: ' + $CombinedUsageTotalsChf.Count) 


    ###########################################################################################################################################################
    #
    # Summarize cost for each Resource - for some Resource Types (e.g. Storage Accounts) cost is listed for individual items
    #
    ###########################################################################################################################################################
    $SumCombinedUsageTotalsChf = $CombinedUsageTotalsChf | Sort-Object Grouping | Group-Object -Property ResourceName | `
    Select-Object -Property name,@{n="SumCost";e={$_.group | ForEach-Object -begin {$i=0} -process {$i+=$_.Cost} -end {$i}}} 

    # Combine the first two tables
    $FinalResult = foreach ($SumCombinedUsageTotalChf in $SumCombinedUsageTotalsChf)
    {
      $Record = ($CombinedUsageTotalsChf | Where-Object {$_.ResourceName -eq $SumCombinedUsageTotalChf.Name}) | Select-Object -First 1

      [PSCustomObject]@{ResourceGroupName = $Record.ResourceGroupName; `                        ResourceName = $Record.ResourceName; `                        Cost = $SumCombinedUsageTotalChf.SumCost; `                        Tag = $Record.Tag; `
      }    
    }
    Write-Verbose -Message ('TEC0009-RecordsToBeWrittenToLogAnalytics: ' + $FinalResult.Count) 


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
    foreach ($Item in $CombinedUsageTotalsChf)
    {                        `
      $Json += @"
      {"ResourceGroupName":"$($Item.ResourceGroupName)", "ResourceName":"$($Item.ResourceName)", "Cost":"$($Item.Cost)", "Tag":"$($Item.Tag)"},
"@
    }
    
    # Add Resource Groups to body - required as Tag for budget is on RG level and RG are no supplied with billing data
    foreach ($Subscription in $Subscriptions)
    {
      $Result = Add-AzureRmAccount -Credential $Credentials -Subscription $Subscription.Name
      Write-Verbose -Message ('TEC0009-RetrieveResourceGroupsForSubscription: ' + ($Result | Out-String))
      $ResourceGroups = Get-AzureRmResourceGroup
    
      foreach ($ResourceGroup in $ResourceGroups)
      {                        `
        $Json += @"
        {"ResourceGroupName":"$($ResourceGroup.ResourceGroupName)", "ResourceName":"", "Cost":"", "Tag":"$($ResourceGroup.Tags.'Monatliche-Kosten')"},
"@
      }
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