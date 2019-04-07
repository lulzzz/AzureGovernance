This repository contains detailed information and IaC (Infrastructure as Code) to perform an Azure foundational setup as well as deploy individual Azure Resource Types. The foundational setup essentially operationalizes Azure. The result is a foundation that is ready to receive business workloads in a secure and controlled fashion. 

While this repository hosts all information and artifacts to do so, it might be advisable to opt for a [series of three workshops](Workshops) to kickstart your Azure deployment.  

![](https://github.com/fbodmer/AzureGovernance/wiki/Home.png)

# Azure Functional Specification
This [Functional Specification document](Azure-Functional-Specification.docx) describes the Azure components required to create, deploy and support new development, test, and production services and capabilities on Microsoft’s Azure Cloud platform using IaaS and PaaS services. The document is covering the topics as outlined in the [Azure Enterprise Scaffold](https://docs.microsoft.com/en-us/azure/architecture/cloud-adoption/appendix/azure-scaffold). 

The document covers the foundational setup of Azure covering processes, architecture and design. It doesn’t address how individual Resource Types are deployed and used but focusses on the fabric into which these resources are deployed – the exception being the Resource Types required to build this foundation. 
Based on this documentation the individual Subscriptions are configured along with resources for networking, monitoring (financial, security), automation etc. This setup can be performed manually via the portal of by developing IaC (Infastructure as Code) artifacts. 

 
Audience
The document has been prepared for a technical audience, covering both architecture/engineering and operations. The assumption is that readers have a basic understanding of Azure.
The structure is such that SME (Subject Matter Experts) can read individual chapters, that are of interest to them.


# Service Specifications
Service Specifications define how individual Azure Resource types are operationalized. The assumption is that each Azure Resource type being used is not simply being deployed via the portal or arbitrary IaC artifacts. Instead Azure design patterns are defined and assessed from a process, financial, security, availability and performance point of view. The resulting document is approved by all involved parties and serves as the baseline for the development of the IaC artifacts.
 
This can be thought of as AaaS (Azure as a Service), defining the consumable Azure Resource types and their characteristics. A Cosmos DB example:
* Table API model only – not other models supported
* Master keys stored in Azure Key Vault instance
* Scheduled key rotation using Azure Automation
* Firewalls configurable by Network team only
* Automatic backup – no custom backups
* Metrics/logs forwarded to central Log Analytics instance in Core Subscription
* Options provided for this design pattern:
  - DB Replication
  - VNET integration

While this is not a must, Service Specifications are ideally defined and implemented as Services in the ITIL Service Request portal (hence the name). This ensures a fully automated end-to-end solution. 

## Published Service Specifications
[Resource Groups](Resource-Groups)<br/>
[Azure Web App](Azure-Web-App)<br/>

# Overall Design
A comprehensive overview of the foundational setup as well as all the design patterns documented in the individual Service Specifications. This illustrates how individual Resource Types are deployed into the foundational framework. This [document](Azure-Overall-Design.vsdx) covers the foundational setup documented in this GitHub repository.


# Infrastructure as Code (IaC)
A repository containing all IaC artifacts. These artifacts are developed based on the Functional Specification and the Service Specifications. These IaC implementations are based on PowerShell and/or ARM templates.  

**Solution Runbooks**<br/>
[SOL0001-AzureSubscriptionNew](SOL0001)<br/>
[SOL0011-ResourceGroupNew](SOL0011)<br/>
[SOL0150-ServerWindowsNew](SOL0150)<br/>
[SOL0155-ServerWindowsNewFromDisk](SOL0155)<br/>
[SOL0300-AppsWebAppNew](SOL0300)<br/><br/>
[XOL0012-ResourceGroupNew](XOL0012)<br/>

**Pattern Runbooks**<br/>
[PAT0010-AzureResourceGroupNew](PAT0010)<br/>
[PAT0050-NetworkVnetNew](PAT0050)<br/>
[PAT0056-NetworkSecurityGroupNew](PAT0056)<br/>
[PAT0058-NetworkSecurityGroupSet](PAT0058)<br/>
[PAT0100-StorageAccountNew](PAT0100)<br/>
[PAT0250-SecurityKeyVaultNew](PAT0250)<br/>
[PAT0300-MonitoringWorkspaceNew](PAT0300)<br/>
[PAT2900-SnowCmdbServerNew](PAT2900)<br/>
[PAT2901-SnowRitmUpdate](PAT2901)<br/>
[PAT2902-SnowRestWindows](PAT2902)<br/>

**Technical Runbooks**<br/>
[TEC0001-TagExport](TEC0001)<br/>
[TEC0002-TagImport](TEC0002)<br/>
[TEC0003-GitHubImportIndividual](TEC0003)<br/>
[TEC0004-GitHubImportAll](TEC0004)<br/>
[TEC0005-AzureContextSet](TEC0005)<br/>
[TEC0007-ExportPowerShellModules](TEC0007)<br/>
[TEC0008-ImportPowerShellModules](TEC0008)<br/>
[TEC0009-CostControl](TEC0009)<br/>
[TEC0010-ExportUsageData](TEC0010)<br/>
[TEC0011-ResourceGroupCreationMonitor](TEC0011)<br/>
[TEC0012-ReportExportToCsv](TEC0012)<br/>
[TEC0013-KeyRotation](TEC0013)<br/>



