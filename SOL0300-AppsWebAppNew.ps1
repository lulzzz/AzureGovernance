###############################################################################################################################################################
# Creates a new App Service Plan and a Web App. Connects the Web App with a GitHub repository. Registers the Web App in AAD and
# configures AAD Authentication/Authorization. 
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       SOL0300-AppsWebAppNew -GitHubRepo $GitHubRepo -ResourceGroupName $ResourceGroupName -AppServicePlanName $AppServicePlanName `
#                                       -WebAppName $WebAppName -SubscriptionCode $SubscriptionCode -RegionName $RegionName -RegionCode $RegionCode
#
# Change log:
# 1.0             Initial version 
# 2.0             Migration to Az modules with use of Set-AzContext
#
###############################################################################################################################################################
workflow SOL0300-AppsWebAppNew
{
  [OutputType([string])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $GitHubRepo = '/fbodmer/felportal',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-co-rsg-automation-01',
    [Parameter(Mandatory=$false)][String] $AppServicePlanNameIndividual = 'portal-02',
    [Parameter(Mandatory=$false)][String] $WebAppNameIndividual = 'portal-02',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'co',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu'
  )


  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureAD, Az.Accounts, Az.Resources, Az.Websites, Microsoft.PowerShell.Utility
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet
  
  
  InlineScript
  {
    $ResourceGroupName = $Using:ResourceGroupName
    $AppServicePlanNameIndividual = $Using:AppServicePlanNameIndividual
    $WebAppNameIndividual = $Using:WebAppNameIndividual
    $GitHubRepo = $Using:GitHubRepo
    $SubscriptionCode = $Using:SubscriptionCode
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name CRE-AUTO-AutomationUser -Verbose:$false
    $CustomerShortCode = Get-AutomationVariable -Name VAR-AUTO-CustomerShortCode -Verbose:$false

    $AppServicePlanName = $RegionCode + '-' + $SubscriptionCode + '-asp-' + $CustomerShortCode + $AppServicePlanNameIndividual
    $WebAppName = $RegionCode + '-' + $SubscriptionCode + '-aps-' + $CustomerShortCode + $WebAppNameIndividual

    Write-Verbose -Message ('SOL0300-AppServicePlanName: ' + ($AppServicePlanName | Out-String))
    Write-Verbose -Message ('SOL0300-WebAppName: ' + ($WebAppName | Out-String))

   
    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = DisConnect-AzAccount
    $AzureContext = Set-AzContext -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('SOL0300-AzureContextChanged: ' + ($AzureContext | Out-String))


    #############################################################################################################################################################
    #
    # Create the Azure App Service Plan
    #
    #############################################################################################################################################################
    $AppServicePlan = New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Location $RegionName -Tier Free -Name $AppServicePlanName

    Write-Verbose -Message ('SOL0300-AppServicePlanCreated: ' + ($AppServicePlan | Out-String))


    #############################################################################################################################################################
    #
    # Create the Azure Web App an connect to GitHub repository
    #
    #############################################################################################################################################################
    $WebApp = New-AzWebApp -ResourceGroupName $ResourceGroupName -Location $RegionName -AppServicePlan $AppServicePlanName -Name $WebAppName

    # Connect the Azure Web App to the GitHub Repository
    $PropertiesObject = @{
        repoUrl = "https://github.com$GitHubRepo";
        branch = "master";
        isManualIntegration = "true";
    }
    $Result = Set-AzResource -PropertyObject $PropertiesObject -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/sites/sourcecontrols `
                                  -ResourceName ($WebAppName + '/web') -ApiVersion 2018-11-01 -Force

    Write-Verbose -Message ('SOL0300-WebAppCreated: ' + ($WebApp | Out-String))


    #############################################################################################################################################################
    #
    # Create the AAD registration for Azure Web App - New-AzADApplication can't be used:
    # https://blogs.msdn.microsoft.com/azuregov/2017/12/06/web-app-easy-auth-configuration-using-powershell/
    #
    #############################################################################################################################################################
    # Login to AAD
    $AzContext = Get-AzContext
    $AzureAd = Connect-AzureAD -TenantId $AzContext.Tenant.Id -Credential $AzureAutomationCredential
    
    # Parameters
    $SiteUri = ('https://' + $WebApp.DefaultHostName)
    $Password = [System.Convert]::ToBase64String($([guid]::NewGuid()).ToByteArray())
    $loginBaseUrl = 'https://login-us.microsoftonline.com/'
    $issuerUrl = $loginBaseUrl +  $AzureAd.Tenant.Id.Guid + "/"
    $Guid = New-Guid
    
    $startDate = Get-Date     
    $PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
    $PasswordCredential.StartDate = $startDate
    $PasswordCredential.EndDate = $startDate.AddYears(1)
    $PasswordCredential.Value = $Password

    $displayName = $WebApp.Name
    [string[]]$replyUrl = $SiteUri + "/.auth/login/aad/callback"

    $reqAAD = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.RequiredResourceAccess'
    $reqAAD.ResourceAppId = "00000002-0000-0000-c000-000000000000"
    $delPermission1 = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess' -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope"            # User.Read permission
    $reqAAD.ResourceAccess = $delPermission1

    # Create app registration in AAD
    $appReg = New-AzureADApplication -DisplayName $displayName -IdentifierUris $SiteUri -Homepage $SiteUri -ReplyUrls $replyUrl `
                                     -PasswordCredential $PasswordCredential -RequiredResourceAccess $reqAAD

    Write-Verbose -Message ('SOL0300-WebAppRegistrationCreated: ' + ($appReg | Out-String))


    #############################################################################################################################################################
    #
    # Configure Azure Web App
    #
    #############################################################################################################################################################
    $WebAppSiteConfiguration = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/sites/config `
                                         -ResourceName ($WebAppName + '/authsettings') -Action list -ApiVersion 2018-11-01 -Force
    Write-Verbose -Message ('SOL0300-ExistingConfiguration: ' + ($WebAppSiteConfiguration | Out-String))

 
    $WebAppSiteConfiguration.properties.enabled = "True"
    $WebAppSiteConfiguration.properties.unauthenticatedClientAction = "RedirectToLoginPage"
    $WebAppSiteConfiguration.properties.tokenStoreEnabled = "True"
    $WebAppSiteConfiguration.properties.defaultProvider = "AzureActiveDirectory"
    $WebAppSiteConfiguration.properties.isAadAutoProvisioned = "False"
    $WebAppSiteConfiguration.properties.clientId = $appReg.AppId
    $WebAppSiteConfiguration.properties.clientSecret = $Password
    $WebAppSiteConfiguration.properties.issuer = $IssuerUrl
 
    $WebAppSiteConfiguration = New-AzResource -PropertyObject $WebAppSiteConfiguration.properties -ResourceGroupName $ResourceGroupName `
                                                   -ResourceType Microsoft.Web/sites/config -ResourceName ($WebAppName + '/authsettings') -ApiVersion 2018-11-01 `
                                                   -Force
    Write-Verbose -Message ('SOL0300-ConfigurationUpdated: ' + ($WebAppSiteConfiguration | Out-String))

  }
}
