###############################################################################################################################################################
# Creates a Resource Group in a single or multiple Regions. Applies Policies and assigns Contributor and Reader roles to the provided AAD Security Groups.  
# The Policy 'Allowed Locations' can be set to 0-6 Regions in accordance with the Policy set on Subscription level. 
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0011-ResourceGroupNew
{
  [OutputType([object])] 	

  param
  (
    [object]$WebhookData 
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #
  # Assign/map data received by REST call from SNOW, to PowerShell variables
  #
  #############################################################################################################################################################
  $WebhookName = $WebhookData.WebhookName
  $RequestHeader = $WebhookData.RequestHeader
  $RequestBody = $WebhookData.RequestBody
  Write-Verbose -Message ('SOL0011-WebhookName: ' + $WebhookName)
  Write-Verbose -Message ('SOL0011-RequestHeader: ' + $RequestHeader)
  Write-Verbose -Message ('SOL0011-RequestBody: ' + $RequestBody)
  Write-Verbose -Message ('SOL0011-WebhookData: ' + $WebhookData)

  $Attributes = ConvertFrom-Json -InputObject $RequestBody
  Write-Verbose -Message ('SOL0011-Attributes: ' + $Attributes)

  $Regions = $Attributes.Attribute01
  $SubscriptionName = $Attributes.Attribute02
  $ResourceGroupNameIndividual = $Attributes.Attribute03
  $IamContributorGroupName = $Attributes.Attribute04
  $ApplicationId = $Attributes.Attribute05
  $CostCenter = $Attributes.Attribute06
  $Budget = $Attributes.Attribute07
  $Contact = $Attributes.Attribute08

  Write-Verbose -Message ('SOL0011-Regions: ' + $Regions)
  Write-Verbose -Message ('SOL0011-SubscriptionName: ' + $SubscriptionName)
  Write-Verbose -Message ('SOL0011-ResourceGroupNameIndividual: ' + $ResourceGroupNameIndividual)
  Write-Verbose -Message ('SOL0011-IamContributorGroupName: ' + $IamContributorGroupName)
  Write-Verbose -Message ('SOL0011-ApplicationId: ' + $ApplicationId)
  Write-Verbose -Message ('SOL0011-CostCenter: ' + $CostCenter)
  Write-Verbose -Message ('SOL0011-Budget: ' + $Budget)
  Write-Verbose -Message ('SOL0011-Contact: ' + $Contact)

      
  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
  $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
  $SubscriptionCode = $SubscriptionName.Split('-')[1]
  Write-Verbose -Message ('SOL0011-SubscriptionCode: ' + ($SubscriptionCode))

  $IamReaderGroupName = 'AzureReader-Reader' 
  $AllowedLocations = 'West Europe,North Europe'                                                                                                                 # Allowed Locations policy 'West Europe,North Europe'

  # Create a 'string table' with the required Regions, containing the name and shortcode (West Europe, weu)
  Write-Verbose -Message ('SOL0011-Regions: ' + ($Regions))
  $RegionTable = InlineScript 
  {
    $Regions = $Using:Regions
    $Regions = $Regions.Split(',')
    foreach ($Region in $Regions)
    { 
      $RegionCode = switch ($Region) 
      {   
        'West Europe' {'weu'} 
        'North Europe' {'neu'}
        'West US' {'wus'}
        'East US' {'eus'}
        'Southeast Asia' {'sea'}
        'East Asia' {'eas'}
      }
      $Entry = $Region + ',' + $RegionCode
      if ($Table.Length -eq 0)
      {
        $Table = $Entry                                                                                                                                          # Ensure first line is not empty
      }
      else
      {
        $Table = $Table,$Entry
      }
    }
    Return $Table
  }
  Write-Verbose -Message ('SOL0011-RegionTable: ' + ($RegionTable | Out-String))

  foreach ($Region in $RegionTable)
  {
    ###########################################################################################################################################################
    #
    # Create Resource Groups
    #
    ###########################################################################################################################################################
    $ResourceGroupName = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual $ResourceGroupNameIndividual `                                                       -IamContributorGroupName $IamContributorGroupName -IamReaderGroupName $IamReaderGroupName `                                                       -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                       -RegionCode (($Region -Split(','))[1]) `                                                       -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact
    Write-Verbose -Message ('SOL0011-ResourceGroupCreated: ' + ($ResourceGroupName))

    
    ###########################################################################################################################################################
    #
    # Configure policies
    #
    ###########################################################################################################################################################
    InlineScript
    { 
      $ResourceGroupName = $Using:ResourceGroupName
      $AllowedLocations = $Using:AllowedLocations

      # Get Policy
      $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

      # Requires nested Hashtable with Region in 'westeurope' format
      $Locations = @((($AllowedLocations -Split(',')) -replace '\s','').ToLower())
      $Locations = @{"listOfAllowedLocations"=$Locations}
      Write-Verbose -Message ('SOL0011-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupName).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + ($ResourceGroupName))
    }
  }
}