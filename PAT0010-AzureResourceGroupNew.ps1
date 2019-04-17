###############################################################################################################################################################
# Creates a Resource Group (e.g. weu-te-rsg-core-01) with Tags. The counter in the name is determined based on the existing Resource Groups.
# Assigns Contributor and Reader roles to the provided AD Security Groups. 
# 
# Output:         $ResourceGroupName
#
# Requirements:   See Import-Module in code below / AD Security Groups
#
# Template:       PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual $ResourceGroupNameIndividual `
#                                               -SubscriptionCode $SubscriptionCode -IamContributorGroupName $IamContributorGroupName `
#                                               -IamReaderGroupName $IamReaderGroupName -RegionName $RegionName -RegionCode $RegionCode `
#                                               -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact
#                                                     
# Change log:
# 1.0             Initial version
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow PAT0010-AzureResourceGroupNew
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ResourceGroupNameIndividual = 'felixtest',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'te',
    [Parameter(Mandatory=$false)][String] $IamContributorGroupName = 'AzureNetwork-Contributor',
    [Parameter(Mandatory=$false)][String] $IamReaderGroupName = 'AzureReader-Reader',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'Application-001',                                                                                    # Tagging
    [Parameter(Mandatory=$false)][String] $CostCenter = 'A99.2345.34-f',                                                                                         # Tagging
    [Parameter(Mandatory=$false)][String] $Budget = '100',                                                                                                       # Tagging
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
    $Result = Import-Module AzureAD, Az.Accounts, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $ResourceGroupName = InlineScript
  {
    $ResourceGroupNameIndividual = $Using:ResourceGroupNameIndividual
    $SubscriptionCode = $Using:SubscriptionCode
    $IamContributorGroupName = $Using:IamContributorGroupName
    $IamReaderGroupName = $Using:IamReaderGroupName
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $ApplicationId = $Using:ApplicationId 
    $CostCenter = $Using:CostCenter 
    $Budget = $Using:Budget 
    $Contact = $Using:Contact


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Automation = Get-AutomationVariable -Name VAR-AUTO-AutomationVersion -Verbose:$false
    $TenantId = ((Get-AzContext).Tenant).Id

    Write-Verbose -Message ('PAT0010-ResourceGroupNameIndividual: ' + ($ResourceGroupNameIndividual))
    Write-Verbose -Message ('PAT0010-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0010-IamContributorGroupName: ' + ($IamContributorGroupName))
    Write-Verbose -Message ('PAT0010-IamReaderGroupName: ' + ($IamReaderGroupName))
    Write-Verbose -Message ('PAT0010-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0010-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0010-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0010-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0010-Budget: ' + ($Budget))
    Write-Verbose -Message ('PAT0010-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0010-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0010-TenantId: ' + ($TenantId))

   
    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = DisConnect-AzAccount
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0010-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Resource Group name
    #
    ###########################################################################################################################################################
    $ResourceGroupName = ($RegionCode + '-' + $SubscriptionCode + '-' + 'rsg' + '-' + $ResourceGroupNameIndividual).ToLower()                                    # e.g. weu-te-rsg-core
    $ResourceGroupExisting = Get-AzResourceGroup `
    |                        Where-Object {$_.ResourceGroupName -like "$ResourceGroupName*"} `
    |                        Sort-Object Name -Descending | Select-Object -First $True

    if ($ResourceGroupExisting.Count -gt 0)                                                                                                                      # Skip if first RG with this name
    {
      Write-Verbose -Message ('PAT0010-ResourceGroupHighestCounter: ' + ($ResourceGroupExisting.ResourceGroupName))
      $Counter = 1 + ($ResourceGroupExisting.ResourceGroupName.SubString(($ResourceGroupExisting.ResourceGroupName).Length-2,2))                                 # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $ResourceGroupName = $ResourceGroupName + '-' + $Counter1                                                                                                  # Compile name    
    }
    else
    {
      $ResourceGroupName = $ResourceGroupName + '-' + '01'                                                                                                       # Compile name for first RG with this name
    }
    Write-Verbose -Message ('PAT0010-ResourceGroupName: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Check if Resource Group exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzResourceGroup -Name $ResourceGroupName -Location $RegionName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Verbose -Message ('PAT0010-ResourceGroupExisting: ' + ($ResourceGroupName))
      Return
    }
  
    try
    {
      $ResourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $RegionName -Verbose:$false
      Write-Verbose -Message ('PAT0010-ResourceGroupCreated: ' + ($ResourceGroupName))
    }
    catch
    {
      Write-Error -Message ('PAT0010-ResourceGroupNotCreated: ' + ($Error[0]))
      Return
    }
  

    ###########################################################################################################################################################
    #
    # Configure AD Groups as Contributor and Reader of the Resource Group
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser 
    $Result = Connect-AzureAD -TenantId $TenantId -Credential $AzureAutomationCredential

    # Assign Contributor Group
    $IamContributorGroup = Get-AzureAdGroup -SearchString $IamContributorGroupName -ErrorAction SilentlyContinue
    if ($IamContributorGroup.Count -ne 1)
    {
      Write-Error -Message ('PAT0010-IamContributorGroupNotFound: ' + ($Error[0]))
    }
    else
    {
      Write-Verbose -Message ('PAT0010-IamContributorGroup: ' + ($IamContributorGroup)) 
      $RoleAssignment = New-AzRoleAssignment -ObjectId $IamContributorGroup.ObjectId  -RoleDefinitionName Contributor -Scope $ResourceGroup.ResourceId
      Write-Verbose -Message ('PAT0010-IamContributorGroupAssigned: ' + ($RoleAssignment))       
    }

    # Assign Reader Group
    $IamReaderGroup = Get-AzureAdGroup -SearchString $IamReaderGroupName -ErrorAction SilentlyContinue
    if ($IamReaderGroup.Count -ne 1)
    {
      Write-Error -Message ('PAT0010-IamReaderGroupNotFound: ' + ($Error[0]))
    }
    else
    {
      Write-Verbose -Message ('PAT0010-IamReaderGroup: ' + ($IamReaderGroup)) 
      $RoleAssignment = New-AzRoleAssignment -ObjectId $IamReaderGroup.ObjectId  -RoleDefinitionName Reader -Scope $ResourceGroup.ResourceId
      Write-Verbose -Message ('PAT0010-IamReaderGroupAssigned: ' + ($RoleAssignment))       
    }

  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0010-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzResourceGroup -Name $ResourceGroupName -Tag $Tags -Verbose:$false
    Write-Verbose -Message ('PAT0010-ResourceGroupTagged: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Return Resource Group name
    #
    ###########################################################################################################################################################
    Return $ResourceGroupName
  }
  Return $ResourceGroupName
}
