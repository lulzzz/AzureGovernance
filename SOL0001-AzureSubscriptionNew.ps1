###############################################################################################################################################################
# Creates and configures a Subscription. Subscriptions with a shortcode 'co' are created as Hub Subscriptions, all other as Spoke Subscriptions.
# A single Subscription can cover any of six Azure Regions. 
# This baseline implementation can be enhanced by submitting additional Service Requests. 
#
# Output:         None
#
# Requirements:   See Import-Module in code below / Execution on Hybrid Runbook Worker as the Firewalls are access on Private IP addresses
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
# 1.1             Remove multi-region deployment
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow SOL0001-AzureSubscriptionNew
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
    $Result = Import-Module Az.Storage, Az.OperationalInsights, Az.Accounts, Az.Resources, AzTable
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
  Write-Verbose -Message ('SOL0001-WebhookName: ' + $WebhookName)
  Write-Verbose -Message ('SOL0001-RequestHeader: ' + $RequestHeader)
  Write-Verbose -Message ('SOL0001-RequestBody: ' + $RequestBody)
  Write-Verbose -Message ('SOL0001-WebhookData: ' + $WebhookData)

  $Attributes = ConvertFrom-Json -InputObject $RequestBody
  Write-Verbose -Message ('SOL0001-Attributes: ' + $Attributes)

  $SubscriptionName = $Attributes.Attribute01
  $SubscriptionOwner = $Attributes.Attribute02
  $SubscriptionOfferType = $Attributes.Attribute03
  $RegionName = $Attributes.Attribute04
  $IamContributorGroupNameNetwork = $Attributes.Attribute05
  $IamContributorGroupNameCore = $Attributes.Attribute06
  $IamContributorGroupNameSecurity = $Attributes.Attribute07
  $IamReaderGroupName = $Attributes.Attribute08
  $ApplicationId = $Attributes.Attribute09
  $CostCenter = $Attributes.Attribute10
  $Budget = $Attributes.Attribute11
  $Contact = $Attributes.Attribute12
  $FirstRegion = $Attributes.Attribute13

      
  Write-Verbose -Message ('SOL0001-SubscriptionName: ' + $SubscriptionName)
  Write-Verbose -Message ('SOL0001-SubscriptionOwner: ' + $SubscriptionOwner)
  Write-Verbose -Message ('SOL0001-SubscriptionOfferType: ' + $SubscriptionOfferType)
  Write-Verbose -Message ('SOL0001-Region: ' + $RegionName)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameNetwork: ' + $IamContributorGroupNameNetwork)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameCore: ' + $IamContributorGroupNameCore)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameSecurity: ' + $IamContributorGroupNameSecurity)
  Write-Verbose -Message ('SOL0001-IamReaderGroupName: ' + $IamReaderGroupName)
  Write-Verbose -Message ('SOL0001-ApplicationId: ' + $ApplicationId)
  Write-Verbose -Message ('SOL0001-CostCenter: ' + $CostCenter)
  Write-Verbose -Message ('SOL0001-Budget: ' + $Budget)
  Write-Verbose -Message ('SOL0001-Contact: ' + $Contact)
  Write-Verbose -Message ('SOL0001-FirstRegion: ' + $FirstRegion)


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $AzureAutomationCredential =  Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
  $MailCredentials = Get-AutomationPSCredential -Name CRE-AUTO-MailUser -Verbose:$false                                                                          # Needs to use app password due to two-factor authentication
  $WorkspaceNameCore = Get-AutomationVariable -Name VAR-AUTO-WorkspaceCoreName                                                                                   # For non-Core Subscriptions
  $PortalUrl = Get-AutomationVariable -Name VAR-AUTO-PortalUrl -Verbose:$false
  $SubscriptionCode = $SubscriptionName.Split('-')[1]
  $ResourceGroupNameCore = "aaa-$SubscriptionCode-rsg-core-01"                                                                                                   # Required if $FirstRegion = 'no'
  $ResourceGroupNameNetwork = "aaa-$SubscriptionCode-rsg-network-01"                                                                                             # Required if $FirstRegion = 'no'
  $ResourceGroupNameSecurity = "aaa-$SubscriptionCode-rsg-security-01"                                                                                           # Required if $FirstRegion = 'no'
  $ResourceGroupNames = @()
  $ResourceGroupNames = $ResourceGroupNameNetwork, $ResourceGroupNameCore, $ResourceGroupNameSecurity
  $StorageAccountNameIndividual = 'diag'                                                                                                                         # For diagnostics Storage Account
  $StorageAccountType = 'standard'
  $RuleSetName = 'default'                                                                                                                                       # For NSG configuration

  # Create the Region Code
  $RegionCode = InlineScript 
  {
    switch ($Using:RegionName) 
    {   
      'West Europe' {'weu'} 
      'North Europe' {'neu'}
      'West US' {'wus'}
      'East US' {'eus'}
      'Southeast Asia' {'sea'}
      'East Asia' {'eas'}
     }
  }
  Write-Verbose -Message ('SOL0001-SubscriptionCode: ' + ($SubscriptionCode))
  Write-Verbose -Message ('SOL0001-ResourceGroupNames: ' + ($ResourceGroupNames))
  Write-Verbose -Message ('SOL0001-RegionTable: ' + ($RegionCode | Out-String))
  Write-Verbose -Message ('SOL0001-StorageAccountNameIndividual: ' + ($StorageAccountNameIndividual))
  Write-Verbose -Message ('SOL0001-StorageAccountType: ' + ($StorageAccountType))
  Write-Verbose -Message ('SOL0001-RuleSetName: ' + ($RuleSetName))


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


  #############################################################################################################################################################
  #  
  # Create Subscription
  #
  #############################################################################################################################################################
  #New-AzSubscription -OfferType $SubscriptionOfferType -Name $SubscriptionCode -EnrollmentAccountObjectId <enrollmentAccountId> `
  #                        -OwnerSignInName $SubscriptionOwner

  
  #############################################################################################################################################################
  #
  # Change context to the new Subscription and load Resource Providers
  #
  #############################################################################################################################################################
  $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode}
  $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))

  # No Log Analytics instances deployed in Hub Subscriptions - which means the Resource Provider is not activiated but is required for registration
  $Result = Register-AzResourceProvider -ProviderNamespace microsoft.insights


  #############################################################################################################################################################
  #  
  # Create Core Resource Groups with Contributor/Reader Groups and Policies - these are created once as they are used for all Regions
  #
  #############################################################################################################################################################
  if ($FirstRegion -eq 'yes')
  {
    # Create Networking Resource Group, e.g. aaa-co-rsg-network-01
    $ResourceGroupNameNetwork = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual network -SubscriptionCode $SubscriptionCode `
                                                              -IamContributorGroupName $IamContributorGroupNameNetwork `
                                                              -IamReaderGroupName $IamReaderGroupName `
                                                              -RegionName $RegionName -RegionCode aaa -Contact $Contact `
                                                              -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget


    # Create Core Resource Group, e.g. weu-co-rsg-core-01
    $ResourceGroupNameCore = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual core -SubscriptionCode $SubscriptionCode `
                                                           -IamContributorGroupName $IamContributorGroupNameCore -IamReaderGroupName $IamReaderGroupName `
                                                           -RegionName $RegionName -RegionCode aaa `
                                                           -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact 

    
   # Create Security Resource Group, e.g. weu-co-rsg-security-01
   $ResourceGroupNameSecurity = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual security -SubscriptionCode $SubscriptionCode `
                                                              -IamContributorGroupName $IamContributorGroupNameSecurity -IamReaderGroupName $IamReaderGroupName `
                                                              -RegionName $RegionName -RegionCode aaa `
                                                              -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact

  }


  # Assign and update Policies - always assign both Regions in a Geo Region
  InlineScript
  { 
    $ResourceGroupNames = $Using:ResourceGroupNames
    $RegionName = $Using:RegionName

    foreach ($ResourceGroup in $ResourceGroupNames)
    {
      # Get Policy
      $Policy = Get-AzPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}
      
      # Get existing Policy Assignment locations as Hashtable
      $PolicyAssignment = Get-AzPolicyAssignment -Name $Policy.Properties.displayName -ErrorAction SilentlyContinue `
                                                 -Scope ((Get-AzResourceGroup -Name $ResourceGroup).ResourceId)
      $Locations = @()
      $Locations = $PolicyAssignment.Properties.parameters.listOfAllowedLocations.value
      
      # Additional Regions
      if ($RegionName -match 'Europe')
      {
        $Locations = $Locations + 'northeurope', 'westeurope'
      }
      elseif ($RegionName -match 'US')
      {
        $Locations = $Locations + 'eastus', 'westus'
      }
      elseif ($RegionName -match 'Asia')
      {
        $Locations = $Locations + 'southeastasia', 'eastasia'
      }
      $Locations = @{"listOfAllowedLocations"=$Locations}
      Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzResourceGroup -Name $ResourceGroup).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0001-ResourceGroupPoliciesApplied: ' + ($ResourceGroup))
    }
  }

  # Wait to ensure Policies are applied
  Start-Sleep -Seconds 60


  #############################################################################################################################################################
  #  
  # Create Diagnostic Storage Account in each Region - used as a central collection point for diagnostic data in the Subscription
  #
  #############################################################################################################################################################
  $StorageAccountName = PAT0100-StorageAccountNew -StorageAccountNameIndividual $StorageAccountNameIndividual `
                                                  -ResourceGroupName "aaa-$SubscriptionCode-rsg-core-01" `
                                                  -StorageAccountType $StorageAccountType `
                                                  -SubscriptionCode $SubscriptionCode -RegionName  $RegionName `
                                                  -RegionCode $RegionCode -Contact $Contact


  #############################################################################################################################################################
  #  
  # This is for Core Subscriptions only - Create Core Storage Account and populate with NSG csv and IPAM Table - in First Region only
  #
  #############################################################################################################################################################
  if($SubscriptionCode -eq 'co' -and $FirstRegion -eq 'yes')
  { 
    # Create Storage Account in each region
    $StorageAccountName = PAT0100-StorageAccountNew -StorageAccountNameIndividual 'core' `
                                                    -ResourceGroupName "aaa-$SubscriptionCode-rsg-core-01" `
                                                    -StorageAccountType $StorageAccountType `
                                                    -SubscriptionCode $SubscriptionCode -RegionName $RegionName `
                                                    -RegionCode $RegionCode -Contact $Contact

    # Reset context - this time with the Core Storage Account
    TEC0005-AzureContextSet

    # Populate with NSG CSV and IPAM Table
    InlineScript
    {
      # Download Runbook NsgRuleSets.csv from GitHub
      $GitHubRepo = '/fbodmer/AzureGovernance'
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      $NsgRuleSets = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents/NsgRuleSets.csv" -UseBasicParsing
      $NsgRuleSetsContent = $NsgRuleSets.Content | ConvertFrom-Json
      $NsgRuleSetsContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::` 
      FromBase64String($NsgRuleSetsContent.content))
      $Result = Out-File -InputObject $NsgRuleSetsContent -FilePath D:\NsgRuleSets.csv -Force
      Write-Verbose -Message ('TEC0003-NsgRuleSetsDownloadedFromGit: ' + ($NsgRuleSetsContent | Out-String))

      # Create File Share and upload NsgRuleSets.csv
      $StorageShare = New-AzStorageShare -Name nsg-rule-set -Context $StorageContext
      Set-AzStorageFileContent -ShareName nsg-rule-set -Source D:\NsgRuleSets.csv -Context $StorageContext

      # Download Runbook Ipam.csv from GitHub
      $GitHubRepo = '/fbodmer/AzureGovernance'
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      $IpamContent = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents/Ipam.csv" -UseBasicParsing
      $IpamContent = $IpamContent.Content | ConvertFrom-Json
      $IpamContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::` 
      FromBase64String($IpamContent.content))
      $Result = Out-File -InputObject $IpamContent -FilePath D:\Ipam.csv -Force
      $IpamContent = Import-Csv -Path D:\Ipam.csv

      # Create Azure Table for IPAM and load data
      $Table = New-AzStorageTable -Name Ipam
      $Table = (Get-AzStorageTable -Name Ipam -Context $StorageContext).CloudTable
      foreach ($Entity in $IpamContent)
      {
        $Result = Add-AzTableRow -Table $Table -PartitionKey $Entity.PartitionKey -RowKey $Entity.RowKey `
                                               -Property @{
                                                             "IpAddress"=$Entity.IpAddress
                                                             "IpAddressAssignment"=$Entity.IpAddressAssignment
                                                             "SubnetIpRange"=$Entity.SubnetIpRange
                                                             "SubnetName"=$Entity.SubnetName
                                                             "VnetIpRange"=$Entity.VnetIpRange
                                                             "VnetName"=$Entity.VnetName
                                                           }
      }
    }
  

    #############################################################################################################################################################
    #
    # Create default Log Analytics Workspaces - in First Region only
    #
    #############################################################################################################################################################
    if ($FirstRegion -eq 'yes')
    {  
      # Create the Core Workspace, e.g. felweucocore01
      $ResourceGroupNameCore = 'aaa' + $ResourceGroupNameCore.Substring(3)
      $WorkspaceNameCore = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual core -ResourceGroupName $ResourceGroupNameCore `
                                                          -SubscriptionCode $SubscriptionCode -RegionName $RegionName `
                                                          -RegionCode $RegionCode -Contact $Contact 
      Write-Verbose -Message ('SOL0001-LogAnalyticsCoreWorkspaceCreated: ' + ($WorkspaceNameCore))

      # Create the Security Workspace, e.g. felweucosecurity01
      $ResourceGroupNameSecurity = 'aaa' + $ResourceGroupNameSecurity.Substring(3)
      $WorkspaceNameSecurity = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual security -ResourceGroupName $ResourceGroupNameSecurity `
                                                              -SubscriptionCode $SubscriptionCode -RegionName $RegionName `
                                                              -RegionCode $RegionCode -Contact $Contact
      Write-Verbose -Message ('SOL0001-LogAnalyticsSecuirtyWorkspaceCreated: ' + ($WorkspaceNameSecurity))
    }

    # Connect the Azure AD diagnostics to the Security Log Analytics Workspace - applies to Core Subscriptions only ???
    $WorkspaceCore = Get-AzOperationalInsightsWorkspace -Name $WorkspaceNameSecurity -ResourceGroupName $ResourceGroupNameSecurity
    #$Result = Set-AzDiagnosticSetting -ResourceId $Subscription.Id -WorkspaceId $WorkspaceCore.ResourceId -Enabled $true

    Write-Verbose -Message ('PAT0056-AzureAdLogsAddedToSecurityLogAnalyticsWorkspace: ' + ($Result | Out-String))
  }


  #############################################################################################################################################################
  #
  # Connect the Subscription to the Core Log Analytics Workspace - for logging of Subscription Activities
  #
  #############################################################################################################################################################
  # Change context to Core Subscription
  $CoreSubscription = Get-AzSubscription | Where-Object {$_.Name -match 'co'}
  $AzureContext = Set-AzContext -Subscription $CoreSubscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))

  # Connect to Workspace
  $WorkspaceCore = Get-AzOperationalInsightsWorkspace | Where-Object {$_.Name -match $WorkspaceNameCore}
  $Result = New-AzOperationalInsightsAzureActivityLogDataSource -WorkspaceName $WorkspaceNameCore `
                                                                     -ResourceGroupName $WorkspaceCore.ResourceGroupName -Force `
                                                                     -SubscriptionId $Subscription.Id -Name $SubscriptionName

  Write-Verbose -Message ('PAT0056-AzureActivityLogsAddedToCoreLogAnalyticsWorkspace: ' + ($Result | Out-String))

  # Change context back to Subscription to be built
  $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode}
  $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))


  #############################################################################################################################################################
  #  
  # Create NSGs for Frontend and Backend Subnets in Security Resource Group, connect with Log Analytics Workspace (diagnostics logs only, no NSG flows)
  #
  #############################################################################################################################################################
  $NsgNames = PAT0056-NetworkSecurityGroupNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName `
                                              -RegionCode $RegionCode -Contact $Contact
  Write-Verbose -Message ('SOL0001-NsgCreated: ' + ($NsgNames))


  #############################################################################################################################################################
  #  
  # Create VNET with Frontend/Backend Subnets, Route Table for Frontend in Network Resource Group and connect with NSG. Configure Service Endpoints.
  #
  #############################################################################################################################################################
  $VnetName = PAT0050-NetworkVnetNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `
                                     -Contact $Contact


  #############################################################################################################################################################
  #  
  # Apply 'Default' NSG Rule Set to NSG created above for Frontend and Backup Subnets
  #
  #############################################################################################################################################################
  $NsgNames = $NsgNames.Split(',')
  foreach ($NsgName in $NsgNames)                                                                                                                              # There are two NSG per Region
  {
    $Result = PAT0058-NetworkSecurityGroupSet -NsgName $NsgName -SubscriptionCode $SubscriptionCode -RuleSetName $RuleSetName
  }


  #############################################################################################################################################################
  #  
  # Create default Key Vault in Security Resource Group
  #
  #############################################################################################################################################################
  $KeyVaultName = PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual 'vault' `
                                              -ResourceGroupName "aaa-$SubscriptionCode-rsg-security-01" `
                                              -SubscriptionCode $SubscriptionCode -RegionName $RegionName `
                                              -RegionCode $RegionCode -Contact $Contact


  #############################################################################################################################################################
  #
  # Configure policies on Subscription level - Allowed locations limited to: West Europe / North Europe / West US / East US / Southeast Aisa / East Asia
  #
  #############################################################################################################################################################
  if ($FirstRegion -eq 'yes')
  {   
  InlineScript
    { 
      $SubscriptionId = $Using:Subscription.Id
      $Policy = Get-AzPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

      # Requires nested Hashtable with Region in 'westeurope' format
      $Locations = @('westeurope', 'northeurope', 'westus', 'eastus', 'southeastasia', 'eastasia')
      $Locations = @{"listOfAllowedLocations"=$Locations}
      Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
      $Result = New-AzPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy -Scope ('/subscriptions/' + $SubscriptionId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0001-SubscriptionPoliciesApplied: ' + ($SubscriptionId))
    }
  }


  #############################################################################################################################################################
  #
  # Update CMDB
  #
  #############################################################################################################################################################
  # This has to be added based on the chosen CMDB implementation


  #############################################################################################################################################################
  #
  # Send Mail confirmation
  #
  #############################################################################################################################################################
  $RequestBody = $RequestBody -Replace('","', "`r`n  ")
  $RequestBody = $RequestBody -Replace('@', '')
  $RequestBody = $RequestBody -Replace('{"', '')
  $RequestBody = $RequestBody -Replace('"}', '')
  $RequestBody = $RequestBody -Replace('":"', ' = ')
  $RequestBody = $RequestBody -Replace('  Attribute', 'Attribtue')
 
  try
  {
    Send-MailMessage -To $SubscriptionOwner -From $MailCredentials.UserName -Subject "Subscription $SubscriptionName has been provisioned" `
                                            -Body $RequestBody -SmtpServer smtp.office365.com  -Credential $MailCredentials -UseSsl -Port 587
    Write-Verbose -Message ('SOL0007-ConfirmationMailSent')
  }
  catch
  {
    Write-Error -Message ('SOL0007-ConfirmationMailNotSent')
  }
}
