﻿###############################################################################################################################################################
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
    $Result = Import-Module Az.Resources
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
  $MailCredentials = Get-AutomationPSCredential -Name CRE-AUTO-MailUser -Verbose:$false                                                                          # Needs to use app password due to two-factor authentication
  $PortalUrl = Get-AutomationVariable -Name VAR-AUTO-PortalUrl -Verbose:$false
  $SubscriptionCode = $SubscriptionName.Split('-')[1]
  Write-Verbose -Message ('SOL0011-SubscriptionCode: ' + ($SubscriptionCode))

  $IamReaderGroupName = 'AzureReader-Reader' 

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
        $Table = $Table, $Entry
      }
    }
    Return $Table
  }
  Write-Verbose -Message ('SOL0011-RegionTable: ' + ($RegionTable | Out-String))


  #############################################################################################################################################################
  #  
  # Ensure request is received from portal
  #
  #############################################################################################################################################################
  if ($WebhookData.RequestHeader -match $PortalUrl)
  {
    Write-Verbose -Message ('SOL0011-Header: Header has required information')
  }
  else
  {
    Write-Error -Message ('SOL0011-Header: Header does not contain required information')
    return
  }

  foreach ($Region in $RegionTable)
  {
    ###########################################################################################################################################################
    #
    # Create Resource Groups
    #
    ###########################################################################################################################################################
    $ResourceGroupName = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual $ResourceGroupNameIndividual `
                                                       -IamContributorGroupName $IamContributorGroupName -IamReaderGroupName $IamReaderGroupName `
                                                       -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `
                                                       -RegionCode (($Region -Split(','))[1]) `
                                                       -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact
    Write-Verbose -Message ('SOL0011-ResourceGroupCreated: ' + ($ResourceGroupName))

    
    ###########################################################################################################################################################
    #
    # Configure policies
    #
    ###########################################################################################################################################################
    InlineScript
    { 
      $ResourceGroupName = $Using:ResourceGroupName
      $Region = $Using:Region

      # Get Policy
      $Policy = Get-AzPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

      # Requires nested Hashtable with Region in 'westeurope' format
      if ($Region -match 'Europe')
      {
        $Locations = @()
        $Locations = 'northeurope', 'westeurope'
      }
      elseif ($Region -match 'US')
      {
        $Locations = @()
        $Locations = 'eastus', 'westus'
      }
      elseif ($Region -match 'Asia')
      {
        $Locations = @()
        $Locations = 'southeastasia', 'eastasia'
      }
      $Locations = @{"listOfAllowedLocations"=$Locations}
      Write-Verbose -Message ('SOL0011-AllowedLocation: ' + ($Locations | Out-String))

      # Assign Policy
      $Result = New-AzPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzResourceGroup -Name $ResourceGroupName).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + ($ResourceGroupName))
    }


    #############################################################################################################################################################
    #
    # Send Mail confirmation
    #
    #############################################################################################################################################################
    $Body = "
              Azure Region: $Regions
              SubscriptionName: $SubscriptionName
              ResourceGroupName: $ResourceGroupName
              Owner (Access): $IamContributorGroupName
              Application ID: $ApplicationId
              Cost Center: $CostCenter
              Budget:$Budget
              Owner (Tag): $Contact
            "
    try
    {
      Send-MailMessage -To $Contact -From $MailCredentials.UserName -Subject "The Resource Group $ResourceGroupName has been provisioned" `
                                    -Body $Body -SmtpServer smtp.office365.com  -Credential $MailCredentials -UseSsl -Port 587
      Write-Verbose -Message ('SOL0011-ConfirmationMailSent')
    }
    catch
    {
      Write-Error -Message ('SOL0011-ConfirmationMailNotSent')
    }   
  }
}

