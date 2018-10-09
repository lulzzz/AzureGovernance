###############################################################################################################################################################
# Creates a new instance of an Azure Analysis Service based on the input parameters.
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   ???
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0011-CreateResourceGroup
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ServiceRequester = 'felix.bodmer@felix.bodmer.name',
    [Parameter(Mandatory=$false)][String] $Region = 'West US',
    [Parameter(Mandatory=$false)][String] $Environment = 'Test',
    [Parameter(Mandatory=$false)][String] $NameIndividual = 'testrg',
    [Parameter(Mandatory=$false)][String] $WorkSpaceId = '/subscriptions/ae747229-5897-4d01-93bb-284e69893c47/resourceGroups/wus-pr-rg-dba-01/providers/Microsoft.OperationalInsights/workspaces/felwusprdba01',
    [Parameter(Mandatory=$false)][String] $Allocation = 'Business',
    [Parameter(Mandatory=$false)][String] $Allocation_Group = 'DIA_HQ',
    [Parameter(Mandatory=$false)][String] $Bill_To = 'I100.35000.07.01.00',
    [Parameter(Mandatory=$false)][String] $Project = 'B0003 (PPNL)',
    [Parameter(Mandatory=$false)][String] $Service_Level = 'Sandpit',
    [Parameter(Mandatory=$false)][String] $MonthlySpend = '1500'
  )
  
  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext
  
  Write-Verbose -Message ('SOL0011-Region: ' + $Region)
  Write-Verbose -Message ('SOL0011-Environment: ' + $Environment) 
  Write-Verbose -Message ('SOL0011-Name: ' + $NameIndividual)
  Write-Verbose -Message ('SOL0011-WorkSpaceId: ' + $WorkSpaceId) 
  Write-Verbose -Message ('SOL0011-Allocation: ' + $Allocation) 
  Write-Verbose -Message ('SOL0011-Allocation_Group: ' + $Allocation_Group)
  Write-Verbose -Message ('SOL0011-Bill_To: ' + $Bill_To) 
  Write-Verbose -Message ('SOL0011-Project: ' + $Project)
  Write-Verbose -Message ('SOL0011-Service_Level: ' + $Service_Level)
  
      
  ###############################################################################################################################################################
  #
  # Create attributes
  #
  ###############################################################################################################################################################
  $RegionShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Region) 
    {   
      'West US'        {'wus'} 
      'West EU'        {'weu'} 
    }
  }
  Write-Verbose -Message ('SOL0011-RegionShortName: ' + $RegionShortName)
  
  $EnvironmentShortName = InlineScript 
  {
    # No upper/lower case defined as they are used in lower and upper case
    switch ($Using:Environment) 
    {   
      'Production'          {'pr'} 
      'Development'         {'de'} 
      'Test'                {'te'}
    }
  }
  Write-Verbose -Message ('SOL0011-EnvironmentShortName: ' + $EnvironmentShortName)
  

  ###############################################################################################################################################################
  #
  # Configure Resource Group name
  #
  ###############################################################################################################################################################
  $ResourceGroupName = $RegionShortName + '-' + $EnvironmentShortName + '-' + 'rg' + '-' + $NameIndividual
  
  $ResourceGroupName = inlineScript
  {
    $ResourceGroupName = $Using:ResourceGroupName
    
    $ResourceGroupExisting = Get-AzureRmResourceGroup `
    |                        Where-Object {$_.ResourceGroupName -like "$ResourceGroupName*"} `
    |                        Sort-Object Name -Descending | Select-Object -First $True
    if ($ResourceGroupExisting.Count -gt 0)                                                                                                                        # Skip if first RG with this name
    {
      Write-Verbose -Message ('SOL0011-ResourceGroupHighestCounter: ' + $ResourceGroupExisting.ResourceGroupName)

      $Counter = 1 + ($ResourceGroupExisting.ResourceGroupName.SubString(($ResourceGroupExisting.ResourceGroupName).Length-2,2))                                   # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                          # Convert to string to get leading '0'
      $ResourceGroupName = $ResourceGroupName + '-' + $Counter1                                                                                                    # Compile name    
    }
    else
    {
      $ResourceGroupName = $ResourceGroupName + '-' + '01'                                                                                                         # Compile name for first RG with this name
    }
    Write-Verbose -Message ('SOL0011-ResourceGroupName: ' + $ResourceGroupName) 
    Return $ResourceGroupName  
  }

  ###############################################################################################################################################################
  #
  # Create Resource Group
  #
  ###############################################################################################################################################################
  try
  {
    $ResourceGroupId = (New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Region).ResourceId
    Write-Verbose -Message ('SOL0011-ResourceGroupCreated: ' + $ResourceGroupName)
  }
  catch
  {
    Write-Error -Message ('SOL0011-ResourceGroupNotCreated: ' + $ReturnCode) 
    Return
  }
  
    
  ###############################################################################################################################################################
  #
  # Configure policies
  #
  ###############################################################################################################################################################
  inlineScript
  {
    $ResourceGroupId = $Using:ResourceGroupId
    
    $Policy = Get-AzureRmPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}
    $Locations = @("West US", "West US 2", "West Europe")
    $Locations = @{"listOfAllowedLocations"=$Locations}
  
    try
    {
      $Result = New-AzureRmPolicyAssignment -Name $Policy.Properties.Displayname -PolicyDefinition $Policy -Scope $ResourceGroupId `
      -PolicyParameterObject $Locations
      Write-Verbose -Message ('SOL0011-ResourceGroupPoliciesApplied: ' + $ResourceGroupName)
    }
    catch
    {
      Write-Error -Message ('SOL0011-ResourceGroupPoliciesNotApplied: ' + $ReturnCode) 
      Suspend-Workflow
      TEC0005-SetAzureContext
    }
  }
  
  
  ###############################################################################################################################################################
  #
  # Create AD Group
  #
  ###############################################################################################################################################################
  inlineScript
  {
    $ResourceGroupName = $Using:ResourceGroupName
    $ResourceGroupId = $Using:ResourceGroupId
    
    $SubscriptionName = Get-AutomationVariable -Name 'VAR-AUTO-SubscriptionName'
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser'
    $AzureAccount = Add-AzureRmAccount -Credential $AzureAutomationCredential -SubscriptionName $SubscriptionName
    $Result = Connect-AzureAD -TenantId $AzureAccount.Context.Tenant.Id -Credential $AzureAutomationCredential
  
    $AdGroupName = $ResourceGroupName + '-owner'
    $AdGroup = New-AzureADGroup -Description $AdGroupName -DisplayName $AdGroupName -MailNickName $AdGroupName -MailEnabled $false -SecurityEnabled $true

    # Ensure AD Group is available
    do
    {
      Start-Sleep -Seconds 20
      $Result = Get-AzureAdGroup -SearchString $AdGroupName
    }
    until ($Result.Count -gt 0)

    ###############################################################################################################################################################
    #
    # Configure AD Group as Owner
    #
    ###############################################################################################################################################################
    $Result = New-AzureRmRoleAssignment -ObjectId $AdGroup.ObjectId  -RoleDefinitionName Owner -Scope $ResourceGroupId
  }
  
  ###############################################################################################################################################################
  #
  # Write tags
  #
  ###############################################################################################################################################################
  $Tags = @{Allocation_Group = $Allocation_Group; Bill_To = $Bill_To; Project = $Project; Service_Level = $Service_Level; Owner = $ServiceRequester; `  Monthly_Spend = $MonthlySpend}
  Write-Verbose -Message ('SOL0011-TagsToWrite: ' + ($Tags | Out-String))
  
  try
  {
    $Result = Set-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags
    Write-Verbose -Message ('SOL0011-TagsWritten: ' + $Result | Out-String)
  }
  catch
  {
    Write-Error -Message ('SOL0011-TagsNotWritten: ' + $ReturnCode) 
    Suspend-Workflow
    TEC0005-SetAzureContext
  }

}