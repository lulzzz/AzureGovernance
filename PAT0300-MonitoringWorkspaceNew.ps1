###############################################################################################################################################################
# Creates a Log Analytics Workspace (e.g. swiweu0010core01) in an existing Resource Group. Tags the created Workspace. 
# Since Log Analytics is not available in all Regions there is a naming violations in certain regions. The name reflects in what region the Log Analytics
# Workspace should be deployed, not where it actually is deployed. 
# 
# Output:         $WorkspaceName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual $WorkspaceNameIndividual -ResourceGroupName $ResourceGroupName `#                                                -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                                -Contact $Contact -Automation $Automation
#                                                     
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow PAT0300-MonitoringWorkspaceNew
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $WorkspaceNameIndividual = 'core',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'aaa-co-rsg-core-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'co',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.OperationalInsights, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $WorkspaceName = InlineScript
  {
    $WorkspaceNameIndividual = $Using:WorkspaceNameIndividual
    $ResourceGroupName = $Using:ResourceGroupName
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

    # Log Analytics is available in certain Azure Regions only
    $RegionNameTechnical = switch ($RegionName) 
    {   
      'West Europe' {'West Europe'} 
      'North Europe' {'West Europe'}
      'West US' {'East US'}
      'East US' {'East US'}
      'Southeast Asia' {'Southeast Asia'}
      'East Asia' {'Southeast Asia'}
    }
     
    Write-Verbose -Message ('PAT0300-WorkspaceNameIndividual: ' + ($WorkspaceNameIndividual))
    Write-Verbose -Message ('PAT0300-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0300-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0300-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0300-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0300-RegionNameTechnical: ' + ($RegionNameTechnical))
    Write-Verbose -Message ('PAT0300-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0300-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0300-CustomerShortCode: ' + ($CustomerShortCode))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0300-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Workspace name
    #
    ###########################################################################################################################################################
    $WorkspaceName = ($CustomerShortCode + $RegionCode + $SubscriptionCode + $WorkspaceNameIndividual)                                                                        # e.g. swiweu0010core01
    $WorkspaceExisting = Get-AzureRmOperationalInsightsWorkspace `
    |                        Where-Object {$_.Name -like "$WorkspaceName*"} `
    |                        Sort-Object Name -Descending | Select-Object -First $True

    if ($WorkspaceExisting.Count -gt 0)                                                                                                                          # Skip if first RG with this name
    {
      Write-Verbose -Message ('PAT0300-WorkspaceHighestCounter: ' + $WorkspaceExisting.Name)
      $Counter = 1 + ($WorkspaceExisting.Name.SubString(($WorkspaceExisting.Name).Length-2,2))                                                                   # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $WorkspaceName = $WorkspaceName + $Counter1                                                                                                                # Compile name    
    }
    else
    {
      $WorkspaceName = $WorkspaceName + '01'                                                                                                                     # Compile name for first RG with this name
    }
    Write-Verbose -Message ('PAT0300-WorkspaceName: ' + $WorkspaceName) 


    ###########################################################################################################################################################
    #
    # Check if Workspace exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzureRmOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Error -Message ('PAT0300-WorkspaceExisting: ' + $WorkspaceName)
      Return
    }
  
    try
    {
      $LogAnalyticsWorkspace = New-AzureRmOperationalInsightsWorkspace -Location $RegionNameTechnical `
                                                                       -Name $WorkspaceName `
                                                                       -ResourceGroupName $ResourceGroupName `
                                                                       -Sku pernode `
                                                                       -ErrorAction Stop                                                                         # pernode is actually 'Per GB'
      Write-Verbose -Message ('PAT0300-LogAnalyticsWorkspaceCreated: ' + ($LogAnalyticsWorkspace | Out-String))
    }
    catch
    {
      Write-Error -Message ('PAT0300-LogAnalyticsWorkspaceNotCreated: ' + $Error[0]) 
      Return
    }

  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{Contact = $Contact; Automation = $Automation}

    Write-Verbose -Message ('PAT0300-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName  -Tag $Tags
    Write-Verbose -Message ('PAT0300-WorkspaceTagged: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Return Workspace name
    #
    ###########################################################################################################################################################
    Return $WorkspaceName
  }
  Return $WorkspaceName
}
