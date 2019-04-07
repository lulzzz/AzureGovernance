### Integrated Development Environment (IDE)
PowerShell ISE with the Azure Automation Add-on is used as the development environment. Optionally [ISESteriods](http://www.powertheshell.com/isesteroids/) is used to enhance developer productivity.<br/>
All development is performed in PowerShell ISE, testing can be executed locally on the workstation or remotely in the Azure Automation Account. The Azure Automation ISE Add-on is used to synch the local development environment on the developers workstation with the Azure Automation Account. There is no direct connection between GitHub and the development Azure Automation Account.<br/>
GitHub Desktop on the developers workstation is used to synch between GitHub and PowerShell ISE. Hence the developers workstation is the integration point between GitHub and the development Azure Automation Account. 

### Hybrid Runbook Worker
All Runbooks are executed on a Hybrid Runbook Worker. This offers the following advantages:
* No Runbooks execution in cloud - singed Runbooks executed on-premise
* Access to on-premise resources behind firewalls
* Execution from a domain joined server, e.g. to enable PowerShell remoting
* Full control over the server on which Runbooks are executed
* Use of AD or local Windows user to execute Runbooks
* Runbooks [TEC0007-ExportPowerShellModules](TEC0007) and [TEC0008-ImportPowerShellModules](TEC0008) to automated PowerShell Module release process. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-1.png" width="1000"><br/>

**RunAs Accounts**<br/>
Azure Automation [RunAs Accounts](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account) are configured for all Azure Automation Accounts as they are used for different purposes. However, all Runbooks on the Hybrid Runbook Workers are executed by a user stored in an Azure Automation Credential Asset. This user is either an AD or local Windows users configured as Windows Administrator on the Hybrid Runbook Worker. 
The PowerShell Module [AzureAutomationAuthoringToolkit](https://www.powershellgallery.com/packages/AzureAutomationAuthoringToolkit/0.2.3.9) needs to be installed under the current user. It can't be installed along with the other Azure Modules. This controlled installation of PowerShell Modules is simplified by not using RunAs Accounts. 


### Test and Production Environment
Separate Azure Automation Accounts are used for Test and Production. The Runbooks are imported from the GitHub Master branch. This is performed by the Runbook TEC0004-GitHubImport. Following are the reasons why the built-in Source Control functionality is not used:<br/>
* Runbooks deleted in GitHub are not deleted in the Azure Automation Account
* Deleting or Runbooks prior to import from GitHub
* Special handling for Runbooks with Webhooks

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-2.png" width="600">

### Branching Model
The following diagram illustrates a possible branching model and the associated Azure Automation accounts.<br/>

**Master**<br/>
Only the Master branch is released into the Production Azure Automation account.<br/>

**Hot Fix**<br/>
Hot fixes are implemented and tested in the Test account and pushed into the Master branch.<br/>

**Bug Fix**<br/>
Bug fixes are implemented, and unit tested in the developers individual accounts. After pushing to the Develop branch, the integration testing is performed in the Test account. After that the Develop branch is pushed to the Master branch for release into Production.<br/>

**Develop**<br/>The Develop branch in the Test account is used for integration testing of the individual bug fixes and new features.<br/>

**Feature**<br/>
New features are handled the same as bug fixes. Developers work in their own Development account.
All development and testing is performed in the Sandbox Subscription as to not impact the production workloads in the Infrastructure and Standard Subscriptions. From an automation point of view only the Sandbox Subscription is not productive.<br/>

The automation in the production environment is performed from the Core Subscription.<br/>
<br/>

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Development-Environment-3.png" width="600">
