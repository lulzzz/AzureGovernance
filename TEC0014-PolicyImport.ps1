###############################################################################################################################################################
# Used to import an individual Azure Policy from GitHub into the selected Subscription. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       TEC0014-PolicyImport -GitHubRepo $GitHubRepo -PolicyName $PolicyName -Category $Category -SubscriptionShortName $SubscriptionShortName
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0014-PolicyImport
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $GitHubRepo = '/fbodmer/AzureGovernance',
    [Parameter(Mandatory=$false)][String] $PolicyName = 'DeployLogAnalyticsAgent',
    [Parameter(Mandatory=$false)][String] $Category = 'Felix',
    [Parameter(Mandatory=$false)][String] $SubscriptionShortName = 'te'
  )
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Accounts, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  InlineScript
  {
    $GitHubRepo = $Using:GitHubRepo 
    $PolicyName = $Using:PolicyName
    $Category = $Using:Category
    $SubscriptionShortName = $Using:SubscriptionShortName

    #############################################################################################################################################################
    #
    # Change to Subscription where policy is imported
    #
    #############################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionShortName} 
    $AzureContext = Connect-AzAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('TEC0014-AzureContext: ' + ($AzureContext | Out-String))    


    ###########################################################################################################################################################
    #  
    # Download Metadata from GitHub
    #  
    ###########################################################################################################################################################
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $PolicyMetadata = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents/Policies/$PolicyName.metadata.json" -UseBasicParsing
    $PolicyMetadata = $PolicyMetadata.Content | ConvertFrom-Json
    $PolicyMetadata = [System.Text.Encoding]::UTF8.GetString([System.Convert]::` 
                      FromBase64String($PolicyMetadata.content))
    Write-Verbose -Message ('TEC0014-PolicyMetadata: ' + ($PolicyMetadata | Out-String))
    $Metadata = @{}
    (ConvertFrom-Json $PolicyMetadata).psobject.properties | ForEach-Object {$Metadata[$_.Name] = $_.Value}                                                   


    ###########################################################################################################################################################
    #  
    # Import Policy from GitHub
    #  
    ###########################################################################################################################################################
    $Result = New-AzPolicyDefinition -Name $Metadata.name `
                                -DisplayName $Metadata.displayname `
                                -Description $Metadata.description `
                                -Policy "https://raw.githubusercontent.com$GitHubRepo/master/Policies/$PolicyName.rule.json" `
                                -Parameter "https://raw.githubusercontent.com$GitHubRepo/master/Policies/$PolicyName.parameters.json" `
                                -Metadata ('{ "category": "' + $Category + '" }') `
                                -Mode All
    Write-Verbose -Message ('TEC0014-PolicyImported: ' + ($Result | Out-String))  
  }
}



