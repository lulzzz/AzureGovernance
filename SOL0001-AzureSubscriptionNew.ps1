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
    $Result = Import-Module Azure.Storage, AzureRM.OperationalInsights, AzureRM.Profile, AzureRM.Resources, AzureRmStorageTable
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
  $Regions = $Attributes.Attribute04
  $IamContributorGroupNameNetwork = $Attributes.Attribute05
  $IamContributorGroupNameCore = $Attributes.Attribute06
  $IamContributorGroupNameSecurity = $Attributes.Attribute07
  $IamReaderGroupName = $Attributes.Attribute08
  $ApplicationId = $Attributes.Attribute09
  $CostCenter = $Attributes.Attribute10
  $Budget = $Attributes.Attribute11
  $Contact = $Attributes.Attribute12

      
  Write-Verbose -Message ('SOL0001-SubscriptionName: ' + $SubscriptionName)
  Write-Verbose -Message ('SOL0001-SubscriptionOwner: ' + $SubscriptionOwner)
  Write-Verbose -Message ('SOL0001-SubscriptionOfferType: ' + $SubscriptionOfferType)
  Write-Verbose -Message ('SOL0001-Regions: ' + $Regions)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameNetwork: ' + $IamContributorGroupNameNetwork)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameCore: ' + $IamContributorGroupNameCore)
  Write-Verbose -Message ('SOL0001-IamContributorGroupNameSecurity: ' + $IamContributorGroupNameSecurity)
  Write-Verbose -Message ('SOL0001-IamReaderGroupName: ' + $IamReaderGroupName)
  Write-Verbose -Message ('SOL0001-ApplicationId: ' + $ApplicationId)
  Write-Verbose -Message ('SOL0001-CostCenter: ' + $CostCenter)
  Write-Verbose -Message ('SOL0001-Budget: ' + $Budget)
  Write-Verbose -Message ('SOL0001-Contact: ' + $Contact)


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $AzureAutomationCredential =  Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
  $MailCredentials = Get-AutomationPSCredential -Name CRE-AUTO-MailUser -Verbose:$false                                                                          # Needs to use app password due to two-factor authentication
  $WorkspaceNameCore = Get-AutomationVariable -Name VAR-AUTO-WorkspaceCoreName                                                                                   # For non-Core Subscriptions
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
 
  $StorageAccountNameIndividual = 'diag'                                                                                                                         # For diagnostics Storage Account
  $StorageAccountType = 'standard'
  $RuleSetName = 'default'                                                                                                                                       # For NSG configuration
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
  # Create Networking Resource Group, e.g. aaa-co-rsg-network-01
  foreach ($Region in $RegionTable)
  {
    $ResourceGroupNameNetwork = PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual network -SubscriptionCode $SubscriptionCode `                                                              -IamContributorGroupName $IamContributorGroupNameNetwork `                                                              -IamReaderGroupName $IamReaderGroupName `                                                              -RegionName (($Region -Split(','))[0]) -RegionCode aaa -Contact $Contact `
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
      Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameNetwork).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0001-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameNetwork))
    }
  }

  # Create Core Resource Group, e.g. weu-co-rsg-core-01
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
      Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameCore).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0001-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameCore))
    }
  }

  # Create Security Resource Group, e.g. weu-co-rsg-security-01
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
      Write-Verbose -Message ('SOL0001-AllowedLocation: ' + ($Locations | Out-String))
      
      # Assign Policy
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy `
                                            -Scope ((Get-AzureRmResourceGroup -Name $ResourceGroupNameSecurity).ResourceId) `
                                            -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0001-ResourceGroupPoliciesApplied: ' + ($ResourceGroupNameSecurity))
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
  # This is for Core Subscriptions only - Create Core Storage Account and populate with NSG csv and IPAM Table in last Region (if multiple are created)
  #
  #############################################################################################################################################################
  if($SubscriptionCode -eq 'co')
  { 
    foreach ($Region in $RegionTable)
    { 
      # Create Storage Account in each region
      $StorageAccountName = PAT0100-StorageAccountNew -StorageAccountNameIndividual 'core' `                                                      -ResourceGroupName "aaa-$SubscriptionCode-rsg-core-01" `                                                      -StorageAccountType $StorageAccountType `                                                      -SubscriptionCode $SubscriptionCode -RegionName  (($Region -Split(','))[0]) `                                                      -RegionCode (($Region -Split(','))[1]) -Contact $Contact
    }

    # Reset context - this time with the Core Storage Account
    TEC0005-AzureContextSet

    # Populate with NSG CSV and IPAM Table - in last region only (if multiple regions are used)
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
      $StorageShare = New-AzureStorageShare -Name nsg-rule-set
      Set-AzureStorageFileContent -ShareName nsg-rule-set -Source D:\NsgRuleSets.csv 

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
      $Table = New-AzureStorageTable -Name Ipam
      foreach ($Entity in $IpamContent)
      {
        $Result = Add-StorageTableRow -table $Table -partitionKey $Entity.PartitionKey -rowKey $Entity.RowKey `
                                      -property @{
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
    # Create default Log Analytics Workspaces
    #
    #############################################################################################################################################################
    # Create the Core Workspace, e.g. felweucocore01
    foreach ($Region in $RegionTable)
    {  
      $ResourceGroupNameCore = 'aaa' + $ResourceGroupNameCore.Substring(3)      $WorkspaceNameCore = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual core -ResourceGroupName $ResourceGroupNameCore `                                                          -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                          -RegionCode (($Region -Split(','))[1]) `                                                          -Contact $Contact 
      Write-Verbose -Message ('SOL0001-LogAnalyticsCoreWorkspaceCreated: ' + ($WorkspaceNameCore))
    }

    # Create the Security Workspace, e.g. felweucosecurity01
    foreach ($Region in $RegionTable)
    {  
      $ResourceGroupNameSecurity = 'aaa' + $ResourceGroupNameSecurity.Substring(3)      $WorkspaceNameSecurity = PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual security -ResourceGroupName $ResourceGroupNameSecurity `                                                              -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                              -RegionCode (($Region -Split(','))[1]) `                                                              -Contact $Contact
      Write-Verbose -Message ('SOL0001-LogAnalyticsSecuirtyWorkspaceCreated: ' + ($WorkspaceNameSecurity))
    }

    # Connect the Azure AD diagnostics to the Security Log Analytics Workspace - applies to Core Subscriptions only ???
    $WorkspaceCore = Get-AzureRmOperationalInsightsWorkspace -Name $WorkspaceNameSecurity -ResourceGroupName $ResourceGroupNameSecurity
    #$Result = Set-AzureRmDiagnosticSetting -ResourceId $Subscription.Id -WorkspaceId $WorkspaceCore.ResourceId -Enabled $true

    Write-Verbose -Message ('PAT0056-AzureAdLogsAddedToSecurityLogAnalyticsWorkspace: ' + ($Result | Out-String))
  }


  #############################################################################################################################################################
  #
  # Connect the Subscription to the Core Log Analytics Workspace - for logging of Subscription Activities
  #
  #############################################################################################################################################################
  # Change context to Core Subscription
  $CoreSubscription = Get-AzureRmSubscription | Where-Object {$_.Name -match 'co'}
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $CoreSubscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))

  # Connect to Workspace
  $WorkspaceCore = Get-AzureRmOperationalInsightsWorkspace | Where-Object {$_.Name -match $WorkspaceNameCore}
  $Result = New-AzureRmOperationalInsightsAzureActivityLogDataSource -WorkspaceName $WorkspaceNameCore -ResourceGroupName $WorkspaceCore.ResourceGroupName `
  -SubscriptionId $Subscription.Id -Name $SubscriptionName

  Write-Verbose -Message ('PAT0056-AzureActivityLogsAddedToCoreLogAnalyticsWorkspace: ' + ($Result | Out-String))

  # Change context back to Subscription to be built
  $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode}
  $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
  Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))


  #############################################################################################################################################################
  #  
  # Create NSGs for Frontend and Backend Subnets in Security Resource Group, connect with Log Analytics Workspace (diagnostics logs only, no NSG flows)
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
    $KeyVaultName = PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual 'vault' `                                                -ResourceGroupName "aaa-$SubscriptionCode-rsg-security-01" `                                                -SubscriptionCode $SubscriptionCode -RegionName (($Region -Split(','))[0]) `                                                -RegionCode (($Region -Split(','))[1]) -Contact $Contact  }


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
      Send-MailMessage -To $SubscriptionOwner -From felix.bodmer@outlook.com -Subject "Subscription $SubscriptionName has been provisioned" `
                                              -Body $RequestBody -SmtpServer smtp.office365.com  -Credential $MailCredentials -UseSsl -Port 587
      Write-Verbose -Message ('SOL0007-ConfirmationMailSent')
    }
    catch
    {
      Write-Error -Message ('SOL0007-ConfirmationMailNotSent')
    }
  }
}