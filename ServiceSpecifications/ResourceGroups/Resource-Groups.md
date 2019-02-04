# Introduction
The smallest deployment unit in Azure is an instance of a Resource Type, aka known as Product or Service. Each of these Service Request Specification documents covers an individual Resource Type.

This specification serves as the baseline for the implementation of the Resource Type as an official offering and the integration of that offering into the operational framework. 

While the specification covers an end-to-end, fully automated service, the actual implementation can be partially or completely based on a manual deployment. 

**Audience**<br/>
This document has been prepared for a technical audience. That is the team responsible for implementing this offering as well as the individuals tasked with operations.

**Purpose of the document**<br/>
The purpose of the document is twofold. It describes how this offering is deployed, operated and decommissioned. It also serves as the blueprint for the implementation of the offering as IaC (Infrastructure as Code). 

**Structure of the document**<br/>
Chapter [Overview](Resource-Groups#Overview) condenses and structures the official documentation in a way to outline what needs to be considered when building and operating this offering. No decisions are captured in this chapter, it’s more a summary of topics to be addressed.

Chapter [Monitoring and Alerting](Resource-Groups#monitoring-and-alerting) addresses the operational requirements with focus on monitoring and alerting. 

Chapter [Usage Patterns](Resource-Groups#usage-patterns)<br/> documents the Usage Patterns and their options. This is essentially the blueprint on how this Azure Resource Type will be implemented as an offering. 

Chapter [Service Requests](Resource-Groups#service-requests) documents how this offering is implemented for consumption by customers. 


# Overview
This chapter outlines the overall design and addresses functional and technical capabilities of Azure Resource Groups. The focus on providing the baseline for the specification of the individual usage patterns outlined in the following chapter.

Resource Groups are used to enable and control what is deployed into a Subscription. In the Standard Subscriptions the deployment and configuration of Resource Groups is tightly controlled with the deployment initiated in the Service Request portal. 

In the Special Subscriptions Resource Groups are created at the discretion of the Subscription Owner. That involves deployment by used of a Service Request, the Azure Portal or programmatically. 

Resource Groups can be used to place all contained Resources under the same lifecycle. It is entirely up to the Resource Group owner if and how to use Resource Groups in that context. 

## Overall Design
Resource Groups are used to enable and control what is deployed into a Subscription. In the Standard Subscriptions the deployment and configuration of Resource Groups is tightly controlled with the deployment initiated in the Service Request portal. In the Special Subscriptions Resource Groups are created at the discretion of the Subscription Owner. That involves deployment by used of a Service Request, the Azure Portal or programmatically. 

Resource Groups can be used to place all contained Resources under the same lifecycle. It is entirely up to the Resource Group owner if and how to use Resource Groups in that context. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/OverallDesign.png" width="500">

 
## Pricing
There is no cost associated with Resource Groups. It is the Resources hosted by the Resource Groups that generate cost.
 
## Stakeholders
The requirements of below stakeholders are addressed in this document. 

**Azure Operations**<br/>
* Ensure deployment in a consistent way, across the organization - following the design outlined in this document.<br/>
* Define SLAs that can be sustained in day-to-day operations.<br/>
* Operational processes supporting BAU and HA/DR situations.<br/>

**Resource Owner**<br/>
* Individuals or groups that order and own a specific Azure Resource. This also includes access to and use of the Azure Resource by developers. 

**Security Officer**<br/>
* Security related setup and configuration during deployment.<br/>
* On-going reporting of security related key parameters.<br/>
* Change control for security relevant re-configurations.<br/>

**Cloud Manager**<br/>
* Responsible for the overall design and operational stability of Azure.<br/>
* Monitoring incurred charges and optimization of spending.<br/>

## Security
### Policies
The Policies are defined in the Functional Specification document.  

### Encryption at Rest
This is not applicable to Resource Groups.

### Encryption in Transfer
This is not applicable to Resource Groups.

### Firewall
This is not applicable to Resource Groups.

### Key Rotation
This is not applicable to Resource Groups.

### Data and Configuration Safety
This is not applicable to Resource Groups.

# Monitoring and Alerting
### Expense Monitoring
Each Resource Group has a Tag ‘Budget’, which captures the expected monthly expenses. At this time, it’s not planned to monitor expenses on individual Resource level, but this could be added if required.
 
Daily, the month-to-date cost is compared with the value captured in the Tag Budget. If a threshold of +20% has been reached an alert is sent to the individual listed in the Tag Responsible as well as to the cloud manager. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/ExpenseMonitoring.png" width="500">

### Security Monitoring
There is no specific security monitoring on Resource Group level. The required out-of-band monitoring is covered on Subscription level and defined in the Functional Specification.

### Performance Monitoring
There is no performance monitoring possible/required on Resource Group level. 


# Usage Patterns
The deployment of a Resource Groups involves not only the actual creation of the Resource Group but also the configuration of RBAC and Policies. There is only a single usage pattern defined for Resource Groups.

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/UsagePattern.png" width="500">


## Naming Convention
The Resource Group naming follows the [overall naming convention](naming-convention):

| | |
| ------------- | ------------- |
| Nomenclature  | `<region>-<subscription>-rsg-<name>-<counter>` | 
| Example | weu-de-rsg-appxy-01 | 
| Description | `<name>` is selected by resource owner `<counter>` determined during deployment |

The region selected during deployment defines where the Resource Group metadata (e.g. Tags) is stored. It has no significance with regards to the Location of the Resouces stored in the Resource Group. The Region code should define where most Resources in the Resource Group are located. In the Core Subscription 'aaa' is used as the Region code for Resource Groups that are not tied to a specific region. 
 
## Access to Resource
### Handover Point and RBAC Models
RBAC configured for a Resource Group depends on the Subscription type and with that the handover point between the Azure Operate team and the Resource Group owner. Default models are used to define the RBAC configuration (see below).

Refer to the document Azure Functional Specification for details on how RBAC is implemented in Azure. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/HandoverPoint.png" width="500">

Unlike Resource Types which have a limited number of built-in roles, it is possible to apply any role on Resource Group level. These roles are inherited by the individual Resources in the Resource Group. The Resource Type specific roles to be applied on Resource Group level are defined in the Service Specification document for the individual Resource Types. 

**Production Subscription**<br/>
In the Production Subscription only the technical Automation user has Owner access to Resource Groups. All others are set to read-only. If required, Azure Operations can be used to assigned temporary Owner or Contributor access to a Subscription. This special authorization needs to be request via a Service Request.

|AD Object Type | Function | Role | Remarks |
| ------------- | ------------- | ------------- | ------------- |
|User | Service Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Co-Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Automation | Owner | Default on all Resources |
|Group/User | Operations | Owner or Contributor | Temporary only |

**Test Subscription**<br/>
In Test the owner of the Resource Group is Azure Operations team. While the deployment is performed in an automation fashion, the Operations team can intervene to remediate problems. Developers are provided with temporary access only, should this be required.<br/>
In the service request portal the deployment of Resource Groups into the Test Subscription should be available to operate teams only.

|AD Object Type | Function | Role | Remarks |
| ------------- | ------------- | ------------- | ------------- |
|User | Service Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Co-Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Automation | Owner | Default on all Resources |
|Group | Azure Operations | Owner | Assigned during initial deployment |
|Group/User | Any| Any | Created by Azure Operations at their own discretion |

**Development Subscription**<br/>
In Development the owner of the Resource Group is assigned the Owner role. This provides full control over the Resource Group, including the assignment of additional users/groups to the Resource Group.

|AD Object Type | Function | Role | Remarks |
| ------------- | ------------- | ------------- | ------------- |
|User | Service Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Co-Administrator | Read-only | Stop inheritance using Deny Assignment |
|User | Automation | Owner | Default on all Resources |
|Group/User | Owner| Owner | Assigned during initial deployment |
|Group/User | Any| Any | Created by Owner at their own discretion |

**Sandbox Subscription**<br/>
In the Sandbox Subscription there is no RBAC implementation. All users have Owner roles assigned and are free to use the Subscription as they please. 

**Special Subscriptions**<br/>
The standard RBAC model is the same as for Development but needs to be assessed on a case-by-case.<br/>

### Functions Mapping<br/>
Below table lists the individual functions provided via the Azure Portal and who should have access to them.

**Category/Function**<br/>
Function available in Azure Portal<br/>

**Operation**<br/>
Azure Resource Manager resource provider operations. This is only required if custom roles are implemented.<br/>

**Assignment**<br/>
Role that is assigned to access/use the function. Different roles are assigned in different Subscription types (Prod/Dev):<br/>
* Resource Group Owner
* Azure Operations
* Automation (Tech User)

|Category/Function | Operation | Assignment | Implications |
| ------------- | ------------- | ------------- | ------------- |
| **General** |  |  | | 		
|Delete Resource Group | - | P: Automation<br/> D: Automation | Irreversibly deleting all Resources |
|Move Resources  | - | Not used | Potentially insecure or unstable environment |
|Delete Resource | - | P: Automation<br/> D: RG Owner | Irreversibly deleting individual Resources |
|Managed Access | - | P: Automation<br/> D: RG Owner | Providing access to unauthorized individuals |
|Manage Tags | - | P: Operations<br/> D: RG Owner | Change of default Tag values |
|Manage Events | - | P: Operations<br/> D: RG Owner | No operational impact |
| **Setting** |  |  |  |
|Manage Policies | - | P: Automation<br/> D: Automation | Compliance violations |
|Manage Deployments | - | P: Not used<br/> D: RG Owner | Potentially insecure or unstable environment |
| **Monitoring** |  |  |  |
|Manage Alerts | - | P: Operations<br/> D: RG Owner | No operational impact |
|Manage Metrics | - | P: Operations<br/> D: RG Owner | No operational impact | 
|Manage Diagnostic | - | P: Operations<br/> D: RG Owner | No operational impact |

### Access Panes
Access to the Resource Group is provided by use of different access panes. It’s important to differentiate between access on the backend to provision, change, monitor and decommission an Azure Resource and front-end access to use the Resource.

Portal:	Access via the Azure Portal using an AAD account -> backend 
PowerShell/REST: Access using PowerShell or direct REST (not via PowerShell) -> backend
URI: Access using an URI with HTTPS (frontend)
Resource native: Access via development tools and repositories

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/AccessPanes.png" width="500">

## Tagging
Below tags are applied to all Resource Groups.<br/>

|Name | Values | Source | Remarks|
| ------------- | ------------- | ------------- | ------------- |
|ApplicationId | Application-ID | Service Request | ID of the application, retrieved from the application inventory|
|CostCenter | Cost Center No. | Service Request	| Cost Center to which the incurred expenses are cross charged|
|Budget | CHF | Service Request | Expected monthly cost for all Resources in the Resource Group|
|Contact | marc.keller@domain.com | Service Request | E-mail address of the person or group responsible for the Resources in the Resource Group. A distinction might be required between financial responsibility and operational responsibility.|
|Automation | Version number | Automation | Version of the Runbooks used for the creation of the Resource Group|
| `<operational>` | Free text | Manual | Operational teams are free to capture additional Tags, required for operational purposes|
 
 
# Service Requests
Possible additional Service Requests to be defined:
* Assign temporary rights
* Change Resource Group
* Move Resource Group
* Decommission Resource Group

## New Resource Group in Azure [SOL0011](SOL0011)
### Catalog Item

|Attribute | Configuration |
| ------------- | ------------- |
|Name | New Resource Group in Azure |
|Icon | <img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/Icon.png" width="50">|
|Location in catalog | Tbd. |
|Accessibility | Anybody with access to the ITIL portal |
|Description | Any Resource in Azure must be deployed into a Resource Group. The Resource Group is not only a container for individual Azure Resources but is also tagged with information used to cross charge the expenses and ensure security compliance.<br/> An Active Directory Group is assigned to the Resource Group in an Owner role. This Active Directory Group needs to exist prior to the execution of this Service Request.|

### Process

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/Process.png" width="800"><br/><br/>
 
**Complete Service Request Form**<br/>
<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/Form.png" width="700"><br/><br/>
 
<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceSpecifications/ResourceGroups/FormRules.png" width="1000"><br/><br/>

**Approve Service Request**<br/>
Standard approval process implemented in ITIL portal.

**Determine Azure Automation Account**<br/>
The ITIL portal needs to maintain a mapping table that maps the selected Azure Subscription to an Automation Account Webhook. The reason being that not each Azure Subscription has an Azure Automation Account configured. 

|Azure Subscription Code | Azure Subscription Name | Automation Account | 
| ------------- | ------------- | ------------- | 
|co | Core-co | weu-co-aut-prod-01 |
|de | Development-de | weu-co-aut-prod-01 |
|te | Test-te | weu-co-aut-prod-01 |
|pr | Production-pr | weu-co-aut-prod-01 |
|sa | Sandbox-sa | weu-sa-aut-test-01 |

**Trigger Runbook in Azure Automation**<br/>
The Runbook in Azure Automation is triggered using a Webhook. The transfer of the form data is in JSON Format. The following example is in PowerShell Format.
```powershell
$JSONBody = @"
 {
    "Attribute02":"weu,West Europe",
    "Attribute01":"co,Core-co",
    "Attribute06":"testgroup",
    "Attribute07":"weu-de-rsg-testgroup-<counter>",
    "Attribute08":"Group1,Mark Miller",
    "Attribute03":"A2,Application2",
    "Attribute04":"1500",
    "Attribute05":"87879.e.9y",
    "Attribute09":"SR38948",
    "Attribute08":"https://itilportal.com",
}
"@

$WebHook = 'https://s13events.azure-automation.net/webhooks?token=<token>'   

# Invokes Azure Automation using REST with Webhook 
Invoke-RestMethod -Uri $WebHook -Body $JSONBody -Method Post
```

**[Create Resource Group (PAT0010)](PAT0010)**<br/>
Create the Resource Group including the following activities:<br/>
* Determine counter
* Configure the standard policies
* Write the Tags
* Configure RBAC<br/>

**Update CMDB (PATnnnn)**<br/>
In all Service Request forms used to deploy Resources in Azure, an existing Resource Group needs to be selected. This information must be retrieved from the CMDB to populate the respective forms. Therefore, the Resource Groups need to be stored in the CMDB. 

Below model illustrates an option on how to model Azure Resources in the CMDB. One of the main questions to be addressed is which redundancies are required:**
* The environment can’t be derived from the Subscription, as Special Subscriptions might contain Resources that are hosted in different environment – Resource Groups could be used to separate environments.
* Collections could be listed as attributes on the individual CI, reducing the number of CI and Relationships. However, most of the collections will be used as List-Of-Values in the Service Request forms. Hence, using collections might be a sensible approach. 

The pattern to be executed depends on the ITIL portal implementation used:<br/>
tbd.<br/>

**Set status of SR to ‘complete’ (PATnnnn)**<br/>
Execute a REST call to change the status of the Service Request in the ITIL portal to ‘complete’. There are no attributes passed back to the ITIL portal as no additional information has been created.

The pattern to be executed depends on the ITIL portal implementation used:<br/>
[PAT2901-SnowRitmUpdate](PAT2901) - used for Service Now

**Handover Report to Service Requester**<br/>
Include the following text in the handover report to the Service Requester:
> The Resource Group `<RessourceGroupName>` has been created in the Azure Subscription `<AzureSubscriptionName>`. The AD Security Group `<AdGroupName>` has been assigned to this Resource Group with an ‘owner’ role. Please use standard IAM processes to request additional users to be added to the AD Group.
