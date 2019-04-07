### Overview
The [development environment](development-environment) is based on a deployment in this [Subscription design](SOL0001). This is relevant only for the creation of the Resource Groups, Automation Account and core Storage Account. For the deployment of the Hybrid Runbook Worker a Log Analytics instance needs to be provisioned.

### Pre-conditions
* Two Azure Subscription are required to deploy this environment. One Subscription is used as a development environment, the other as a test or production environment. Owner rights to the Subscriptions are required. 
* Admin rights to the Azure Active Directory (AAD) to which above Subscriptions are connected.
* Admin rights to the development workstation running Windows 10. If Hybrid Runbook Workers are deployed, they should be used for development. In that case run this installation from the server to be used as Hybrid Runbook Worker. 

### Start ISE
Start ISE using administrator rights. If extensive development is performed it's suggested to use [ISESteroids](http://www.powertheshell.com/isesteroids/) as add-on to ISE.<br/>

Optionally the [PowerShell Gallery](https://www.powershellgallery.com/) could be configured as a trusted repository.<br/>
`Set-PSRepository -Name PSGallery -InstallationPolicy Trusted`

### Install the AzureRm PowerShell module
Install the [AzureRM PowerShell module](https://www.powershellgallery.com/packages/AzureRM/6.8.1), additional modules might be required depending on the Azure Resource Types used. For the Runbooks in this repository there is an [overview of all Runbooks](Runbook-Overview) that lists the modules used by each Runbook:<br/> 
```powershell
Install-Module AzureRM
```

The following, additional modules are required by the Runbooks in this repository:
```powershell
Install-Module AzureRM.Network, AzureRM.Insights, AzureRM.OperationalInsights, `
               AzureRMStorageTable, AzureRM.KeyVault, AzureAD
```

### Create the Core Storage Account
Login to Azure Subscription with a user that has Owner rights:<br/> 
```powershell
Connect-AzureRmAccount -Subscription Core-co
```

Create Resource Group to host the Core Storage Account, adjust the location and Tags as required. The `Automation` Tag is not used as this and the following Resources are created manually.<br/>
```powershell
New-AzureRmResourceGroup -Name aaa-co-rsg-core-01 `
                         -Location WestEurope `
                         -Tags @{
                                  ApplicationId = 'Application-001'; `
                                  CostCenter = 'A99.2345.34-f'; 
                                  Budget = '100'; `
                                  Contact = 'contact@customer.com'; `
                                }
```

Create the Core Storage Account:<br/>
```powershell
New-AzureRmStorageAccount -Name <customershortcode>weucocore01s `
                          -ResourceGroupName aaa-co-rsg-core-01 `
                          -Location WestEurope `
                          -SkuName Standard_LRS `
                          -Tags @{
                                   Contact = 'contact@customer.com'; `
                                 }
```

### Deploy an Azure Automation Instance
Create Resource Group to host the Automation Account, adjust the location and Tags as required:<br/>
```powershell
New-AzureRmResourceGroup -Name weu-co-rsg-automation-01 `
                         -Location WestEurope `
                         -Tags @{
                                  ApplicationId = 'Automation-001'; `
                                  CostCenter = 'A99.2345.34-f'; 
                                  Budget = '100'; `
                                  Contact = 'contact@customer.com'; `
                                }
```

Create the Automation Account, adjust the location and Tags as required. The example Runbooks created along with the Automation Account are not required and can be deleted - there might be a delay until these example Runbooks are displayed.<br/>
```powershell
New-AzureRmAutomationAccount -Name weu-co-aut-prod-01 `
                             -ResourceGroupName weu-co-rsg-automation-01 `
                             -Location WestEurope `
                             -Tags @{
                                       Contact = 'contact@customer.com'; `
                                    }
```

**Create a RunAs Account**<br/>
Use the Azure Portal to create a RunAs Account for the Azure Automation Account created above. Don't create the 'Azure Classic' RunAs Account. This creates an 'App Registration' in the AAD, the name of the Application starting with 'weu-co-aut-dev-01_<uniqueid>'.

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-Setup-2.png" width="500"><br/>

**Update Modules**<br/>
Update the Modules in the newly created Automation Account, this is best done using the Azure portal. This update might have to be triggered multiple times, the module `AzureRM.Profile` should be version 5.8 or later. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-Setup-1.png" width="500"><br/>

### Create an Automation User in Azure Active Directory (AAS)
A technical user is required for the execution of the Azure Automation Runbooks. The Runbooks in this repository don't use the RunAs Account created above. The RunAs Account created above is used for housekeeping purposes by Azure Automation - e.g. for Module updates. Instead of a RunAs Account, technical users with least privileges are used by the Runbooks in this repository.<br/>
It might be advisable to use the standard IAM process and create this user in the on-premise AD, then replicate it to the AAD.<br/>

```powershell
$AzureContext = Get-AzureRmContext
Connect-AzureAD -TenantId $AzureContext.Tenant.Id
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = '<password>'
$PasswordProfile.EnforceChangePasswordPolicy = $false
$PasswordProfile.ForceChangePasswordNextLogin = $false
New-AzureADUser -DisplayName Automation `
                -UserPrincipalName automation@<customerdomain> `
                -AccountEnabled $true `
                -PasswordProfile $PasswordProfile `
                -MailNickName automation
```

### Add Automation User to Subscription
Configure the Automation User with the Owner role on Subscription level. This user must be configured in all Subscriptions that are targeted by Azure Automation.

```powershell
$AdUser = Get-AzureRmADUser -UserPrincipalName 'automation@<customerdomain>'
New-AzureRmRoleAssignment -SignInName $AdUser.UserPrincipalName -RoleDefinitionName Owner
```

### Install the Azure Automation PowerShell ISE add-on
This installs the [Azure Automation PowerShell ISE add-on](https://azure.microsoft.com/en-us/blog/announcing-azure-automation-powershell-ise-add-on/). The module must be installed as 'CurrentUser' to allow for the local assets to be found:<br/>
```powershell
Install-Module AzureAutomationAuthoringToolkit -Scope CurrentUser
```
 
For PowerShell ISE to always automatically load the add-on:<br/>
```powershell
Install-AzureAutomationIseAddOn
```

### Base Path and RunAs
Adjust the 'Base path for runbooks' if required. This is the location where the ISA add-on creates the local repository. This will later also be used as the location for the local GitHub repository.<br/>
Don't use RunAs for execution of Runbooks, de-select the flag.

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-Setup-3.png" width="400">

### Sign-in to Azure Automation
Sign in to Azure Automation and select the correct Subscription and Automation Account. 

### Create and Download Automation Assets
Create the basic Azure Automation assets, this is the minimal set of Azure Automation assets required. For the Runbooks in this repository there is an [overview of all Runbooks](Runbook-Overview) that lists the Azure Automation assets used by each Runbook.<br/>
```powershell
# Enter credentials for technical user for Azure Automation
$Credentials = Get-Credential
New-AzureRmAutomationCredential -AutomationAccountName weu-co-aut-prod-01 `
                                -ResourceGroupName weu-co-rsg-automation-01 `
                                -Name CRE-AUTO-AutomationUser `
                                -Value $Credentials
New-AzureRmAutomationVariable -AutomationAccountName weu-co-aut-prod-01 `
                              -ResourceGroupName weu-co-rsg-automation-01 `
                              -Name VAR-AUTO-SubscriptionName `
                              -Value Core-co `
                              -Encrypt $false
New-AzureRmAutomationVariable -AutomationAccountName weu-co-aut-prod-01 `
                              -ResourceGroupName weu-co-rsg-automation-01 `
                              -Name VAR-AUTO-AutomationAccountName `
                              -Value weu-co-aut-prod-01 `
                              -Encrypt $false
New-AzureRmAutomationVariable -AutomationAccountName weu-co-aut-prod-01 `
                              -ResourceGroupName weu-co-rsg-automation-01 `
                              -Name VAR-AUTO-StorageAccountName `
                              -Value <customershortcode>weucocore01s `
                              -Encrypt $false
New-AzureRmAutomationVariable -AutomationAccountName weu-co-aut-prod-01 `
                              -ResourceGroupName weu-co-rsg-automation-01 `
                              -Name VAR-AUTO-AutomationVersion `
                              -Value v1.0 `
                              -Encrypt $false
New-AzureRmAutomationVariable -AutomationAccountName weu-co-aut-prod-01 `
                              -ResourceGroupName weu-co-rsg-automation-01 `
                              -Name VAR-AUTO-CustomerShortCode `
                              -Value <customershortcode> `
                              -Encrypt $false
```

Download the assets in ISE, re-enter the password for CRE-AUTO-AutomationUser as passwords are not downloaded.


### Import Runbooks from GitHub to Azure Automation
Import the Runbooks [TEC0005-AzureContextSet.ps1](TEC0005) and [TEC0003-GitHubImportIndividual.ps1](TEC0003) or [TEC0004-GitHubImportAll.ps1](TEC0004) from GitHub into the Azure Automation Account. 

```powershell
# Download from GitHub
$GitHubRepo = '/fbodmer/AzureGovernance'
$RunbookName = '<runbookname>'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$RunbookGitHub = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents/$RunbookName" `
                                   -UseBasicParsing
$RunbookContent = $RunbookGitHub.Content | ConvertFrom-Json
$RunbookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::` 
                  FromBase64String($RunbookContent.content))
Out-File -InputObject $RunbookContent -FilePath C:\Windows\Temp\$RunbookName -Force

# Import to Azure Automation
$RgName = 'weu-co-rsg-automation-01'
$AutomationAccountName = Get-AutomationVariable -Name 'VAR-AUTO-AutomationAccountName'
Import-AzureRmAutomationRunbook -ResourceGroupName $RgName `
                                -AutomationAccountName $AutomationAccountName `
                                -Type PowerShellWorkflow `
                                -Path C:\Windows\Temp\$RunbookName `
                                -LogVerbose $true `
                                -Published `
                                -Description 'Imported from GitHub' `
                                -Force
```

### Setup Hybrid Runbook Worker
The following steps are optional, and only required if a Hybrid Runbook Worker is used. For this a server running Windows Server 2012 or later must be available. That server can be on-premise or in Azure. 

**Create Log Analytics Workspace**<br/>
Use the pattern [PAT0300-MonitoringWorkspaceNew](PAT0300) to create a Log Analytics Workspace. The Automation Accounts in all Subscriptions are connected to the Log Analytics Workspace `<customershortcode>weucocore01` in the Resource Group `aaa-co-rsg-core-01`.

**Add Automation solution to Log Analytics Workspace**<br/>
Add the automation solution `AzureAutomation` using below PowerShell scripts or in the Azure Portal.<br/>
```powershell
Set-AzureRmOperationalInsightsIntelligencePack -ResourceGroupName aaa-co-rsg-core-01 `
                                               -WorkspaceName <customershortcode>weucocore01 `
                                               -IntelligencePackName AzureAutomation `
                                               -Enabled $true
```

**Install the Microsoft Monitoring Agent**<br/>
Follow [these instructions](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/agent-windows) to install the Microsoft Monitoring Agent on the server that is used as a Hybrid Runbook Worker.

Connecting the server to a Log Analytics instance will download the HybridRegistration PowerShell module that is used in the next step. In can take quite a long time (an hour or more) for this download to be completed. This PowerShell script can be used instead, but it creates a new Log Analytics instance: https://www.powershellgallery.com/packages/New-OnPremiseHybridWorker/1.5  

**Install the runbook environment and connect to Azure Automation**<br/>
Follow [these instructions](https://docs.microsoft.com/en-us/azure/automation/automation-windows-hrw-install#4-install-the-runbook-environment-and-connect-to-azure-automation) to install the runbook environment on the server that is used as a Hybrid Runbook Worker.

