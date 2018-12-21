###############################################################################################################################################################
# Creates a new Spoke Subscription in it's most basic design. This baseline implementation can be enhanced by submitting additional Service Requests. 
# The Azure Resources included in this basic design can be deployed to one or multiple regions. If a deployment to multiple regions is chosen
# the same Resource Groups and their Resources are deployed to each Region. One exception are the Log Analytics Workspaces that need to be deployed to 
# West Europe, East US or Southeast Asia as they are not available in the other Regions. They will however be deployed to the Resource Group in the respective 
# Region.
#
# Output:         None
#
# Requirements:   See Import-Module in code below / Execution on Hybrid Runbook Worker as the Firewalls are access on Private IP addresses
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow SOL0001-AzureSubscriptionNew
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionName = 'Development-de',
    [Parameter(Mandatory=$false)][String] $SubscriptionOwner = 'owner@customer.com',
    [Parameter(Mandatory=$false)][String] $SubscriptionOfferType = 'MS-AZR-0017P',               
    [Parameter(Mandatory=$false)][String] $Regions = 'West Europe',                                                                                              # 'West Europe,North Europe,West US,Est US,Southeast Asia,East Asia'
    [Parameter(Mandatory=$false)][String] $IamContributorGroupNameNetwork = 'AzureNetwork-Contributor',                                                          # AD Group for Contributor role on Network RSG
    [Parameter(Mandatory=$false)][String] $IamContributorGroupNameCore = 'AzureCore-Contributor',                                                                # AD Group for Contributor role on Core RSG
    [Parameter(Mandatory=$false)][String] $IamContributorGroupNameSecurity = 'AzureSecurity-Contributor',                                                        # AD Group for Contributor role on Security RSG
    [Parameter(Mandatory=$false)][String] $IamReaderGroupName = 'AzureReader-Reader',                                                                     # AD Group for Reader on all RSG
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'Application-001',                                                                                    # Tagging
    [Parameter(Mandatory=$false)][String] $CostCenter = 'A99.2345.34-f',                                                                                         # Tagging
    [Parameter(Mandatory=$false)][String] $Budget = '100',                                                                                                       # Tagging
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'                                                                                      # Tagging                                                                                               # Tagging
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
  $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
  $SubscriptionCode = $SubscriptionName.Split('-')[1]
  Write-Verbose -Message ('SOL0001-SubscriptionCode: ' + ($SubscriptionCode))

  # Create a 'string table' with the required Regions, containing the name and shortcode (West Europe,weu)
  Write-Verbose -Message ('SOL0001-Regions: ' + ($Regions))
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
  Write-Verbose -Message ('SOL0001-RegionTable: ' + ($RegionTable | Out-String))
 
  $StorageAccountNameIndividual = 'diag'
  $StorageAccountType = 'standard'
  $RuleSetName = 'default'
  Write-Verbose -Message ('SOL0001-StorageAccountNameIndividual: ' + ($StorageAccountNameIndividual))
  Write-Verbose -Message ('SOL0001-StorageAccountType: ' + ($StorageAccountType))
  Write-Verbose -Message ('SOL0001-RuleSetName: ' + ($RuleSetName))


  #############################################################################################################################################################
  #  
  # Create Subscription
  #
  #############################################################################################################################################################
  #New-AzureRmSubscription -OfferType $SubscriptionOfferType -Name $SubscriptionCode -EnrollmentAccountObjectId <enrollmentAccountId> `
  #                        -OwnerSignInName $SubscriptionOwner


  #############################################################################################################################################################
  #
  # Change context to the new Subscription
  #
  #############################################################################################################################################################
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode}
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))


  #############################################################################################################################################################
  #  
  # Create Core Resource Groups with Contributor/Reader Groups and Policies in each Region
  #
  #############################################################################################################################################################
  # Create Networking Resource Group, e.g. weu-0005-rsg-network-01
  foreach ($Region in $RegionTable)
  {
    $ResourceGroupNameNetwork = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual network -SubscriptionCode $SubscriptionCode `                                                              -IamContributorGroupName $IamContributorGroupNameNetwork -IamReaderGroupName $IamReaderGroupName `                                                              -RegionName (($Region -Split(','))[0]) -RegionCode aaa -Contact $Contact `
                                                              -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget

    # Assign Policies
    InlineScript
    { 
      $ResourceGroupNameNetwork = $Using:ResourceGroupNameNetwork
      $Region = $Using:Region

      # Get Policy
      $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

      # Requires nested Hashtable with Region in 'westeurope' format
      $Locations = @((($Region -Split(','))[0] -replace '\s','').ToLower())
      $Locations = @{"listOfAllowedLocations"=$Locations}
      Write-Verbose -Message ('SOL0011-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameNetwork).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameNetwork))
    }
  }

  # Create Core Resource Group, e.g. weu-0005-rsg-core-01
  foreach ($Region in $RegionTable)
  {
    $ResourceGroupNameCore = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual core -SubscriptionCode $SubscriptionCode `                                                           -IamContributorGroupName $IamContributorGroupNameCore -IamReaderGroupName $IamReaderGroupName `                                                           -RegionName (($Region -Split(','))[0]) -RegionCode aaa `                                                           -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact 

    # Assign Policies - assign both Regions in a Geo Region due to unavailability of Log Analytics in all Regions
    InlineScript
    { 
      $ResourceGroupNameCore = $Using:ResourceGroupNameCore
      $Region = $Using:Region

      # Get Policy
      $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

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
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameCore).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameCore))
    }
  }

  # Create Security Resource Group, e.g. weu-0005-rsg-security-01
  foreach ($Region in $RegionTable)
  {
    $ResourceGroupNameSecurity = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual security -SubscriptionCode $SubscriptionCode `                                                               -IamContributorGroupName $IamContributorGroupNameSecurity -IamReaderGroupName $IamReaderGroupName `                                                               -RegionName (($Region -Split(','))[0]) -RegionCode aaa `                                                               -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact

    # Assign Policies - assign both Regions in a Geo Region due to unavailability of Log Analytics in all Regions
    InlineScript
    { 
      $ResourceGroupNameSecurity = $Using:ResourceGroupNameSecurity
      $Region = $Using:Region

      # Get Policy
      $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

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
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameSecurity).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameSecurity))
    }
  }


  #############################################################################################################################################################
  #  
  # Create Diagnostic Storage Account - used as a central collection point for diagnostic data in the Subscription
  #
  #############################################################################################################################################################
    foreach ($Region in $RegionTable)
  {  
    $StorageAccountName = PAT0100-StorageAccountNew -StorageAccountNameIndividual $StorageAccountNameIndividual `                                                    -ResourceGroupName "aaa-$SubscriptionCode-rsg-core-01" `                                                    -StorageAccountType $StorageAccountType `                                                    -SubscriptionCode $SubscriptionCode -RegionName  (($Region -Split(','))[0]) `                                                    -RegionCode (($Region -Split(','))[1]) -Contact $Contact  }  


  #############################################################################################################################################################
  #
  # Create default Log Analytics Workspaces
  #
  #############################################################################################################################################################
  # Create the Core Workspace, e.g. felweu0010refcore01
  foreach ($Region in $RegionTable)
  {  
    $ResourceGroupNameCore = 'aaa' + $ResourceGroupNameCore.Substring(3)    $WorkspaceName = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual core -ResourceGroupName $ResourceGroupNameCore `                                                    -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                    -RegionCode (($Region -Split(','))[1]) `                                                    -Contact $Contact
    Write-Verbose -Message ('SOL0001-LogAnalyticsCoreWorkspaceCreated: ' + ($WorkspaceName))
  }

  # Create the Security Workspace, e.g. felweu0010refsecurity01
  foreach ($Region in $RegionTable)
  {  
    $ResourceGroupNameSecurity = 'aaa' + $ResourceGroupNameSecurity.Substring(3)    $WorkspaceName = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual security -ResourceGroupName $ResourceGroupNameSecurity `                                                    -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                    -RegionCode (($Region -Split(','))[1]) `                                                    -Contact $Contact
    Write-Verbose -Message ('SOL0001-LogAnalyticsSecuirtyWorkspaceCreated: ' + ($WorkspaceName))
  }


  #############################################################################################################################################################
  #  
  # Create NSGs for Frontend and Backend Subnets in Security Resource Group, connect with Log Analytics Workspace
  #
  #############################################################################################################################################################
  foreach ($Region in $RegionTable)
  {  
    $NsgNames = PAT0056-NetworkSecurityGroupNew -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                -RegionCode (($Region -Split(','))[1]) -Contact $Contact    Write-Verbose -Message ('SOL0001-NsgCreated: ' + ($NsgNames))
  }


  #############################################################################################################################################################
  #  
  # Create VNET with Frontend/Backend Subnets, Route Table for Frontend in Network Resource Group and connect with NSG. Configure Service Endpoints.
  #
  #############################################################################################################################################################
  foreach ($Region in $RegionTable)
  {  
    $VnetName = PAT0050-NetworkVnetNew -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) -RegionCode (($Region -Split(','))[1]) `                                       -Contact $Contact
  }


  #############################################################################################################################################################
  #  
  # Apply 'Default' NSG Rule Set to NSG created above for Frontend and Backup Subnets
  #
  #############################################################################################################################################################
  foreach ($Region in $RegionTable)
  {  
    $NsgNames = $NsgNames.Split(',')
    foreach ($NsgName in $NsgNames)                                                                                                                              # There are two NSG per Region    {      $Result = PAT0058-NetworkSecurityGroupSet -NsgName $NsgName -SubscriptionCode $SubscriptionCode -RuleSetName $RuleSetName    }
  }


  #############################################################################################################################################################
  #  
  # Create default Key Vault in Security Resource Group
  #
  #############################################################################################################################################################
  foreach ($Region in $RegionTable)
  {  
     $KeyVaultName = PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual 'keyvault' `                                                 -ResourceGroupName "aaa-$SubscriptionCode-rsg-security-01" `                                                 -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                 -RegionCode (($Region -Split(','))[1]) -Contact $Contact  }


  #############################################################################################################################################################
  #
  # Configure policies on Subscription level
  #
  #############################################################################################################################################################
  # Allowed locations limited to: West Europe / North Europe / West US / East US / Southeast Aisa / East Asia
  InlineScript
  { 
    $SubscriptionId = $Using:Subscription.Id
    $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

    # Requires nested Hashtable with Region in 'westeurope' format
    $Locations = @('westeurope', 'northeurope', 'westus', 'eastus', 'southeastasia', 'eastasia')
    $Locations = @{"listOfAllowedLocations"=$Locations}
    Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
    $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy -Scope ('/subscriptions/' + $SubscriptionId) `
                                          -PolicyParameterObject $Locations
    Write-Verbose -Message ('SOL0001-SubscriptionPoliciesApplied: ' + ($SubscriptionId))


  #############################################################################################################################################################
  #
  # Update CMDB
  #
  #############################################################################################################################################################
  # This has to be added based on the chosen CMDB implementation


  #############################################################################################################################################################
  #
  # Update Service Request
  #
  #############################################################################################################################################################
  # This has to be added based on the chosen Service Request portal implementation


  }
}