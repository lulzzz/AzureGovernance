To integrate the deployment of Resources in Azure with an ITIL portal such as ServiceNow we need to differentiate between the process and the technical implementation.

### Process
As with all other Service Requests (SR) the approval process is executed in ServiceNow, but all technical activities related to the deployment of the Resource in Azure is executed in Azure Automation. 

![](https://github.com/fbodmer/AzureGovernance/wiki/ServiceNow-1.png)


### Technical Implementation
The technical implementation corresponds to the process view. 

<img src="https://github.com/fbodmer/AzureGovernance/wiki/ServiceNow-2.png" width="600">


The following Patterns are used in Azure Automation:<br/>
Step 3: [PAT2902-SnowRestWindows](PAT2902)<br/>
Step 6: [PAT2900-SnowCmdbServerNew](PAT2900)<br/>
Step 7: [PAT2901-SnowRitmUpdate](PAT2901)<br/>



