﻿###############################################################################################################################################################
# Creates a Key Vault (e.g. weu-te-key-felkeyvault-01) in an existing Resource Group. Tags the Key Vault. 
# Adds Key Vault to the corresponding Log Analytics Workspace (e.g. felweutesecurity01).
# 
# Output:         $KeyVaultName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual $KeyVaultNameIndividual -ResourceGroupName $ResourceGroupName `
#                                             -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode -Contact $Contact
#
# Change log:
# 1.0             Initial version
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0250-SecurityKeyVaultNew
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $KeyVaultNameIndividual = 'valt',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'aaa-co-rsg-security-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'co',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com'                                                                                      # Tagging
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Monitor, Az.KeyVault, Az.OperationalInsights, Az.Accounts, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $KeyVaultName = InlineScript
  {
    $KeyVaultNameIndividual = $Using:KeyVaultNameIndividual
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

    # Security Log Analytic Workspace in Core Subscription
    $LogAnalyticsWorkspaceName = Get-AutomationVariable -Name VAR-AUTO-WorkspaceSecurityName                                                                     # e.g. felweutesecurity01
    $ResourceGroupNameSecurity = 'aaa-co-rsg-security-01'                                                                                                        # e.g. aaa-te-rsg-security-01

    Write-Verbose -Message ('PAT0250-KeyVaultNameIndividual: ' + ($KeyVaultNameIndividual))
    Write-Verbose -Message ('PAT0250-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0250-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0250-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0250-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0250-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0250-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0250-LogAnalyticsWorkspaceName: ' + ($LogAnalyticsWorkspaceName))
    Write-Verbose -Message ('PAT0250-ResourceGroupNameSecurity: ' + ($ResourceGroupNameSecurity))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0250-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Key Vault name
    #
    ###########################################################################################################################################################
    $KeyVaultName = $RegionCode + '-' + $SubscriptionCode + '-' + 'key' + '-' + $CustomerShortCode + $KeyVaultNameIndividual                                     # e.g. weu-te-key-keyvault-01
    $KeyVaultExisting = Get-AzKeyVault | Where-Object {$_.VaultName -like "$KeyVaultName*"} `
                                            | Sort-Object Name -Descending | Select-Object -First $True
    if ($KeyVaultExisting.Count -gt 0)                                                                                                                           # Skip if first Key Vault with this name
    {
      Write-Verbose -Message ('PAT0250-KeyVaultHighestCounter: ' + ($KeyVaultExisting.VaultName))

      $Counter = 1 + ($KeyVaultExisting.VaultName.SubString(($KeyVaultExisting.VaultName).Length-2,2))                                                           # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $KeyVaultName = $KeyVaultName + '-' + $Counter1                                                                                                            # Compile name    
    }
    else
    {
      $KeyVaultName = $KeyVaultName + '-' + '01'                                                                                                                 # Compile name for first Key Vault with this name
    }
    Write-Verbose -Message ('PAT0250-KeyVaultName: ' + ($KeyVaultName))


    ###########################################################################################################################################################
    #
    # Check if Key Vault exists and create if not
    #
    ###########################################################################################################################################################
    $KeyVault = Get-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($KeyVault.Length -gt 0)
    {
      Write-Verbose -Message ('PAT0250-KeyVaultExisting: ' + ($KeyVaultName))
      Return
    }
  
    try
    {
      $KeyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -Location $RegionName
      Write-Verbose -Message ('PAT0250-KeyVaultCreated: ' + ($KeyVaultName))
    }
    catch
    {
      Write-Error -Message ('PAT0250-KeyVaultNotCreated: ' + ($Error[0]))
      Return
    }

    ###########################################################################################################################################################
    #
    # Add Key Vault to Log Analytics Workspace in Core Subscription e.g. felweutesecurity01
    #
    ###########################################################################################################################################################
    # Change context to Core Subscription
    $CoreSubscription = Get-AzSubscription | Where-Object {$_.Name -match 'co'}
    $AzureContext = Set-AzContext -Subscription $CoreSubscription.Name -Force
    Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))    
    
    # Get Workspace in Core Subscription
    $LogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupNameSecurity
    Write-Verbose -Message ('PAT0056-LogAnalyticsWorkspace: ' + ($LogAnalyticsWorkspace | Out-String))

    # Change context back to Subscription to be built
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode}
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('SOL0001-AzureContextChanged: ' + ($AzureContext | Out-String))    
    
    # Connect Key Vault to Log Analytics Workspace    
    $Result = Set-AzDiagnosticSetting -ResourceId $KeyVault.ResourceId  -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true `
                                      -Category AuditEvent -MetricCategory AllMetrics
    Write-Verbose -Message ('PAT0250-KeyVaultAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))
      
  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0250-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzResource -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.KeyVault/vaults' `
                                  -Tag $Tags -Force
    Write-Verbose -Message ('PAT0250-KeyVaultTagged: ' + ($KeyVaultName))


    ###########################################################################################################################################################
    #
    # Return Resource Group name
    #
    ###########################################################################################################################################################
    Return $KeyVaultName
  }
  Return $KeyVaultName
}

