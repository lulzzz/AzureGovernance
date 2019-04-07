I offer a series of three one day workshops (at CHF 2'000 each) that are based on the contents of this repository. I have worked full time with Azure since the release of Azure Resource Manager, mostly as contractor in Microsoft accounts - all sizes and industries. You can find more about me on [LinkedIn](https://www.linkedin.com/in/felix-bodmer-75564a/). I don't maintain a social media presence or web site but instead put all my efforts into this GitHub repository. 

The workshops and content of this repository are based on years of experience and learnings from working with customers. With every new customer interaction this repository is expanded.

These workshops can be used in the context of new Azure deployments as well as a benchmark to improve existing implementations. The later being more common as most customers are first confronted with Azure when development teams start experimenting on the platform. 

# Day 1 - Azure Functional Specification
The [Functional Specification document](Azure-Functional-Specification.docx) is reviewed and adjusted to individual needs. The document and workshop covers all topics outlined in the [Azure Enterprise Scaffold](https://docs.microsoft.com/en-us/azure/architecture/cloud-adoption/appendix/azure-scaffold). 

Suggested participants include a cross section of all infrastructure teams, cloud managers and DEV/OPS. The goal is to not only produce a customized document but to also transfer knowledge about Azure technology and discuss impact on organizations as well as their processes. 

An additional benefit is that everybody is 'on the same page' after the workshop and existing roadblocks such as concerns about networking and security are addressed. It has proven valuable to organize two breakout sessions (during the day) for security and networking. 


# Day 2 - Automated Resource Group Deployment
The goal of this workshop is to implement an end-to-end solution for the automated deployment of an Azure Resource Group. This includes the configuration of a development environment for Azure Automation, the adjustment of PowerShell and/or ARM template Runbooks ([IaC in this repository](https://github.com/fbodmer/AzureGovernance/wiki#infrastructure-as-code-iac)) and the creation of an Azure Web App to serve as an [ordering portal](https://github.com/fbodmer/FelPortal). 

There are several reason why there is a focus on automation right from the beginning and using Azure Automation to do so. 

### Azure Automation is a must
No matter what automation framework you plan on using, [Azure Automation](https://docs.microsoft.com/en-us/azure/automation/automation-intro) is essential in any reasonably sized Azure environment. Several Azure Resource types use Azure Automation as an integral part of their offering. Log Analytics offerings are often based on Azure Automation. For operational reasons every customer will need to implement housekeeping and governance jobs. Also, Azure Automation is simply the most stable, powerfull and cost efficient (SaaS, almost no runtime cost) product out there. 

### Automation is the Foundation
Meaningful governance in any public cloud can only reasonably be achieved if deployments are automated. This automated deployment needs to be triggered out of existing CI/CD pipelines and/or service requests in the ITIL portal. Sincem covering CI/CD is beyond the scope of this workshop, service requests are used to demonstrate the end-to-end process. As an alternative to deploying the Azure Web App an integration into Service Now or similar ITIL frameworks would be possible. As this would require the respective developers, the practicality of this approach is not always given. Most organizations also like to have a simple, easy to update portal that can be used for triggering deployments that don't required a full blown service request. 

### No Standard without IaC
Standards can only be enforced using automation. It is not reasonable to expect a well governed environment that has been deployed by manual interaction. The same applies to these workshops, having everything available as IaC means it has been deployed before and has been proven. It also leaves more time to discuss the inner workings and reduces the time spent 'clicking in the portal'. 

# Day 3 - Subscription Deployment/Configuration 
This Workshop builds on the first two days. Additional Runbooks are used to build out the Subscriptions. The number and types of Subscriptions has been defined on day 1, the framework for the automated deployment established on day 2. The goal is to build the overall Azure design as outlined in this [document](Azure-Overall-Design.vsdx). The exact number of Subscriptions and Azure Regions covered needs to be adjusted to what was defined on day 1. 

After this workshop participants have a hands-on understanding of what has been established as the customer specific architecture. The organization is ready to start hosting business workloads in a controlled and secure fashion. The important Azure paradigms and design patterns are understood and customer SMEs are empowered to continue evolving the environment to their specific needs. 





