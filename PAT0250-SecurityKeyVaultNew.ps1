###############################################################################################################################################################
# Creates a Key Vault (e.g. weu-0010-key-keyvault-01) in an existing Resource Group. Tags the Key Vault. 
# Adds Key Vault to the corresponding Log Analytics Workspace (e.g. swiweu0010security01).
# 
# Output:         $KeyVaultName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0250-SecurityKeyVaultNew -KeyVaultNameIndividual $KeyVaultNameIndividual -ResourceGroupName $ResourceGroupName `#                                             -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode `#                                             -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact -Automation $Automation
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow PAT0250-SecurityKeyVaultNew
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $KeyVaultNameIndividual = 'keyvault',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-0010-rsg-security-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = '0010',
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
    $Result = Import-Module AzureRM.Insights, AzureRM.KeyVault, AzureRM.OperationalInsights, AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $KeyVaultName = InlineScript
  {
    $KeyVaultNameIndividual = $Using:KeyVaultNameIndividual
    $ResourceGroupName = $Using:ResourceGroupName
    $StorageAccountType = $Using:StorageAccountType
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

    # Log Analytic Workspace
    $LogAnalyticsWorkspaceName = ('swi' + $RegionCode + $SubscriptionCode + 'security01')                                                                        # e.g. swiweu0010security01
    $ResourceGroupNameSecurity = ($RegionCode + "-$SubscriptionCode-rsg-security-01")                                                                            # e.g. weu-0010-rsg-security-01

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
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0250-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Key Vault name
    #
    ###########################################################################################################################################################
    $KeyVaultName = $RegionCode + '-' + $SubscriptionCode + '-' + 'key' + '-' + $KeyVaultNameIndividual                                                          # e.g. weu-0010-key-keyvault-01
    $KeyVaultExisting = Get-AzureRmKeyVault | Where-Object {$_.VaultName -like "$KeyVaultName*"} `
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
    $Result = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Verbose -Message ('PAT0250-KeyVaultExisting: ' + ($KeyVaultName))
      Return
    }
  
    try
    {
      $KeyVault = New-AzureRmKeyVault -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -Location $RegionName
      Write-Verbose -Message ('PAT0250-KeyVaultCreated: ' + ($KeyVaultName))
    }
    catch
    {
      Write-Error -Message ('PAT0250-KeyVaultNotCreated: ' + ($Error[0]))
      Return
    }

    ###########################################################################################################################################################
    #
    # Add Key Vault to Log Analytics Workspace e.g. swiweu0010security01
    #
    ###########################################################################################################################################################
    $LogAnalyticsWorkspace = Get-AzureRmOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupNameSecurity 
    $Result = Set-AzureRmDiagnosticSetting -ResourceId $KeyVault.ResourceId  -WorkspaceId $LogAnalyticsWorkspace.ResourceId -Enabled $true
    Write-Verbose -Message ('PAT0250-KeyVaultAddedToLogAnalyticsWorkspace: ' + ($Result | Out-String))
      
  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0250-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmResource -Name $KeyVaultName -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.KeyVault/vaults' `
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
