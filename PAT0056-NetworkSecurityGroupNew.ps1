###############################################################################################################################################################
# Creates default NSGs for the Frontend (e.g. weu-0010-nsg-vnt01fe) and Backend (e.g. weu-0010-nsg-vnt01fe) Subnets in the '-rsg-security-01' Resource Group. 
# Adds the NSG to the Security Log Analytics Workspace (e.g. swiweu0010security01). Tags the NSGs.
#
# Output:         $NsgFrontendSubnetName, $NsgBackendSubnetName
#
# Requirements:   See Import-Module in code below / Log Analytics Workspace, '-rsg-security-01' Resource Group
#
# Template:       PAT0056-NetworkSecurityGroupNew -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                                 -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact `
#                                                 -Automation $Automation
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0056-NetworkSecurityGroupNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = '0010',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'Application-001',                                                                                    # Tagging
    [Parameter(Mandatory=$false)][String] $CostCenter = 'A99.2345.34-f',                                                                                         # Tagging
    [Parameter(Mandatory=$false)][String] $Budget = '100',                                                                                                       # Tagging
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com',                                                                                     # Tagging
    [Parameter(Mandatory=$false)][String] $Automation = 'v1.0'                                                                                                   # Tagging
  )

  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Insights, AzureRM.Network, AzureRM.OperationalInsights, AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $NsgNames = InlineScript
  { 
    $SubscriptionCode = $Using:SubscriptionCode
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $ApplicationId = $Using:ApplicationId 
    $CostCenter = $Using:CostCenter 
    $Budget = $Using:Budget 
    $Contact = $Using:Contact 
    $Automation = $Using:Automation


    ###########################################################################################################################################################
    #  
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false

    $ResourceGroupName = $RegionCode + '-' + $SubscriptionCode + '-rsg-security-01'                                                                              # e.g. weu-0010-rsg-security-01
    
    # Network Security Groups
    $NsgFrontendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01fe'                                                                              # e.g. weu-0010-nsg-vnt01fe
    $NsgBackendSubnetName = $RegionCode + '-' + $SubscriptionCode + '-nsg-vnt01be'                                                                               # e.g. weu-0010-nsg-vnt01be

    # Log Analytic Workspace
    $LogAnalyticsWorkspaceName = ('swi' + $RegionCode + $SubscriptionCode + 'security01')                                                                        # e.g. swiweu0010security01
    $ResourceGroupNameSecurity = ($RegionCode + "-$SubscriptionCode-rsg-security-01")                                                                            # e.g. weu-0010-rsg-security-01

    Write-Verbose -Message ('PAT0056-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0056-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0056-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0056-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0056-Budget: ' + ($Budget))
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
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0056-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #  
    # Check if NSG already exists
    #
    ###########################################################################################################################################################
    $NsgFrontendSubnet = Get-AzureRmNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($NsgFrontendSubnet.Length -gt '0')
    {
      Write-Error -Message ('PAT0056-NsgAlreadyExisting: ' + ($NsgFrontendSubnet | Out-String))
      Return
    }

    $NsgBackendSubnet = Get-AzureRmNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
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
    # Create Frontend Subnet e.g. weu-0010-sub-vnt01-fe
    $NsgFrontendSubnet = New-AzureRmNetworkSecurityGroup -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0056-NsgFrontSubnetCreated: ' + ($NsgFrontendSubnet | Out-String))

    # Create Backend Subnet e.g. weu-0010-sub-vnt01-be
    $NsgBackendSubnet = New-AzureRmNetworkSecurityGroup -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -Location $RegionName
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetCreated: ' + ($NsgBackendSubnet | Out-String))


    ###########################################################################################################################################################
    #
    # Add NSG to Log Analytics Workspace e.g. swiweu0010security01
    #
    ###########################################################################################################################################################
    $LogAnalyticsWorkspace = Get-AzureRmOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupNameSecurity 
    Write-Verbose -Message ('PAT0056-LogAnalyticsWorkspace: ' + ($LogAnalyticsWorkspace | Out-String))
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnet: ' + ($NsgFrontendSubnet | Out-String))
    Write-Verbose -Message ('PAT0056-NsgBackendSubnet: ' + ($NsgBackendSubnet | Out-String))

    $Result = Set-AzureRmDiagnosticSetting -ResourceId $NsgFrontendSubnet.Id -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true `
                                           -Categories 'NetworkSecurityGroupEvent','NetworkSecurityGroupRuleCounter'
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnetAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))

    $Result = Set-AzureRmDiagnosticSetting -ResourceId $NsgBackendSubnet.Id -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true `
                                           -Categories 'NetworkSecurityGroupEvent','NetworkSecurityGroupRuleCounter'
    Write-Verbose -Message ('PAT0056-NsgBackendSubnetAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))
  

    ###########################################################################################################################################################
    #
    # Create Tags
    #
    ###########################################################################################################################################################
    $Tags = $null
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0056-TagsToWrite: ' + ($Tags | Out-String))

    # NSGs
    $Result = Set-AzureRmResource -Name $NsgFrontendSubnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/networkSecurityGroups' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0056-NsgFrontendSubnetTagged: ' + ($NsgFrontendSubnetName))
    
    $Result = Set-AzureRmResource -Name $NsgBackendSubnetName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Network/networkSecurityGroups' `
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
