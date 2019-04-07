### CMDB

In connection with Azure the significance of a CMDB is greatly reduced. This is due to the fact that a Subscription inherently offers a CMDB. Unlike in an on-premise environments there is no discovery required as all Resources in a Subscription can be queried using REST or PowerShell. This leaves the question on how to proceed with CMDB implementations, what CIs and CI relationships representing Azure Resources should be maintained. How they can be modeled and instantiated.

### Discovery

While most CMDB vendors offer discovery functionality for Azure there are usually a couple pitfalls. They are not likely to discover all of the 100+ Resource Types. If they claim to do so it is unlikely that they can keep their product up-to-date, due to the fast sequence of product announcements by Microsoft. 

### Modelling

When modelling Azure related CIs and CI relationships in a CMDB existing classes of the tool should be used whenever possible. If there are no corresponding classes generic classes are used with a ResoureType attribute or similar denoting the Azure Resource Type. 

The relationships should be kept to a minimum such as the ones outlined in the BMC Atrium model below or [Service Now](PAT2900). Relationships between Resources, Resource Types and Subscriptions need to be modelled. An optional Relationship is the one to an Environment class. This would not be required if Subscriptions represent environments. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Cmdb-1.png" width="500">

### Instantiation

Which CI and CI relationships should be instantiated depends on backend systems and processes that use the CMDB information. One point to consider is that only very few Resource Types are known to these systems and processes - probably limited to VMs and SQL PaaS. All other PaaS services are not likely to be used as they are not available on-premise or in any other cloud. One approach might be to map Resource Types to CI classes that are known to these backend systems, e.g. a Cosmos DB is modelled as a SQL DB or a generic DB. But again, this only works for a few Resource Types as there is not likely anything corresponding for e.g. Cognitive Services. 

### Service Requests

In most products offering ITIL functionality there is a close connection between Service Requests and the CMDB. In most products list of values in a Service Request form are populated from the CMDB. Doing so from some custom table is often more difficult. When implementing a Service Request to e.g. deploy a Cosmos DB the Service Request form needs to be populated with the available Subscriptions and their Resource Groups. This why the requestor can choose where to deploy the new Cosmos DB resource. 
For this reason Subscriptions and Resource groups need to be modelled and instantiated in the CMDB. What else needs to be modelled depends on the requirements, e.g. when deploying multiple SQL databases to a single SQL PaaS Server.







