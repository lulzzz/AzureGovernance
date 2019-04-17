###############################################################################################################################################################
# Creates default NSGs for the Frontend (e.g. weu-te-nsg-vnt01fe) and Backend (e.g. weu-te-nsg-vnt01fe) Subnets in the '-rsg-security-01' Resource Group. 
# Adds the NSG to the Security Log Analytics Workspace (e.g. felweutesecurity01). Tags the NSGs.
#
# Output:         $NsgFrontendSubnetName, $NsgBackendSubnetName
#
# Requirements:   See Import-Module in code below / Log Analytics Workspace, '-rsg-security-01' Resource Group
#
# Template:       PAT0056-NetworkSecurityGroupNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode -Contact $Contact 
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0056-NetworkSecurityGroupNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'te',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'                                                                                     # Tagging
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Monitor, Az.Network, Az.OperationalInsights, Az.Accounts, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $NsgNames = InlineScript
  { 
    $SubscriptionCode = $Using:SubscriptionCode
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $Contact = $Using:Contact 


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
    $CustomerShortCode = Get-AutomationVariable -Name VAR-AUTO-CustomerShortCode -Verbose:$false

    $ResourceGroupName = 'aaa-' + $SubscriptionCode + '-rsg-security-01'                                                                                         # e.g. aaa-te-rsg-security-01
    
    # Network Security Groups
    $NsgFrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01fe'                                                                              # e.g. weu-te-nsg-vnt01fe
    $NsgBackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01be'                                                                               # e.g. weu-te-nsg-vnt01be

    # Security Log Analytic Workspace in Core Subscription
    $LogAnalyticsWorkspaceName = Get-AutomationVariable -Name VAR-AUTO-WorkspaceSecurityName                                                                     # e.g. felweutesecurity01
    $ResourceGroupNameSecurity = 'aaa-co-rsg-security-01'                                                                                                        # e.g. aaa-te-rsg-security-01

    Write-Verbose -Message ('PAT0056-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0056-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0056-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0056-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0056-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0056-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnetName: ' + ($NsgFrontendSubnetName))
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetName: ' + ($NsgBackendSubnetName))
    Write-Verbose -Message ('PAT0056-LogAnalyticsWorkspaceName: ' + ($LogAnalyticsWorkspaceName))
    Write-Verbose -Message ('PAT0056-ResourceGroupNameSecurity: ' + ($ResourceGroupNameSecurity))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = DisConnect-AzAccount
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0056-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #  
    # Check if NSG already exists
    #
    ###########################################################################################################################################################
    $NsgFrontendSubnet = Get-AzNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($NsgFrontendSubnet.Length -gt '0')
    {
      Write-Error -Message ('PAT0056-NsgAlreadyExisting: ' + ($NsgFrontendSubnet | Out-String))
      Return
    }

    $NsgBackendSubnet = Get-AzNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($NsgBackendSubnet.Length -gt '0')
    {
      Write-Error -Message ('PAT0056-NsgAlreadyExisting: ' + ($NsgBackendSubnet | Out-String))
      Return
    }    
      

    ###########################################################################################################################################################
    #  
    # Create NSG for Frontend and Backend Subnets
    #
    ###########################################################################################################################################################
    # Create Frontend Subnet e.g. weu-te-sub-vnt01-fe
    $NsgFrontendSubnet = New-AzNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0056-NsgFrontSubnetCreated: ' + ($NsgFrontendSubnet | Out-String))

    # Create Backend Subnet e.g. weu-te-sub-vnt01-be
    $NsgBackendSubnet = New-AzNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetCreated: ' + ($NsgBackendSubnet | Out-String))


    ###########################################################################################################################################################
    #
    # Add NSG to Log Analytics Workspace in Core Subscription e.g. felweutesecurity01
    #
    ###########################################################################################################################################################
    # Change context to Core Subscription
    $CoreSubscription = Get-AzSubscription | Where-Object {$_.Name -match 'co'}
    $AzureContext = Set-AzContext -Subscription $CoreSubscription.Name -Force
    Write-Verbose -Message ('PAT0056-AzureContextChanged: ' + ($AzureContext | Out-String))    
    
    # Get Workspace in Core Subscription
    $LogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupNameSecurity 
    Write-Verbose -Message ('PAT0056-LogAnalyticsWorkspace: ' + ($LogAnalyticsWorkspace | Out-String))
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnet: ' + ($NsgFrontendSubnet | Out-String))
    Write-Verbose -Message ('PAT0056-NsgBackendSubnet: ' + ($NsgBackendSubnet | Out-String))

    # Change context back to Subscription to be built
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode}
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0056-AzureContextChanged: ' + ($AzureContext | Out-String))

    # Connect NSG to Log Analytics Workspace
    $Result = Set-AzDiagnosticSetting -ResourceId $NsgFrontendSubnet.Id -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true `
                                      -Category NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnetAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))

    $Result = Set-AzDiagnosticSetting -ResourceId $NsgBackendSubnet.Id -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true `
                                      -Category 'NetworkSecurityGroupEvent','NetworkSecurityGroupRuleCounter'
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))
  

    ###########################################################################################################################################################
    #
    # Create Tags
    #
    ###########################################################################################################################################################
    $Tags = $null
    $Tags = @{Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0056-TagsToWrite: ' + ($Tags | Out-String))

    # NSGs
    $Result = Set-AzResource -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/networkSecurityGroups' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnetTagged: ' + ($NsgFrontendSubnetName))
    
    $Result = Set-AzResource -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/networkSecurityGroups' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetTagged: ' + ($NsgBackendSubnetName))


    ###########################################################################################################################################################
    #
    # Create CIs
    #
    ###########################################################################################################################################################
    # This has to be added based on the chosen CMDB implementation

    Return $NsgNames = $NsgFrontendSubnetName + ',' + $NsgBackendSubnetName
  }
  Return $NsgNames
}
