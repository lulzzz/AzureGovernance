### Runbooks
_TTTxxxx-name_<br/>
TTT: Type of Runbook SOL = Solution / PAT = Pattern / TEC = Technical<br/>
xxxx: Unique counter 0000-9999 within Runbook types - see below<br/>
name: Runbook name in camel case - TechnologyTaskAction (use PowerShell verb for Action)<br/>

Use the same SOLxxx but different text for runbooks that are used as dummies for testing. E.g. if the Solution is generally called from ServiceNow but for testing purposes a runbook is used to mimic the REST call.<br/>
SOL0001-WindowsServer<br/>
SOL0001-RestCallDummy<br/>

**Cloud Name Ranges (same for SOL/PAT/TEC)**<br/>
PAT0000 - 2999 Azure<br/>
PAT3000 - 5999 AWS<br/>
PAT6000 - 8999 Google<br/>
PAT9000 - 9999 spare<br/>   

**Name Ranges within Cloud**<br/>
PAT0000 - 0049 ResourceManager<br/>
PAT0050 - 0099 Networking<br/>
PAT0100 - 0149 Storage<br/>
PAT0150 - 0199 Server<br/>
PAT0200 - 0249 Database<br/>
PAT0250 - 0299 Security<br/>
PAT0300 - 0349 Monitoring<br/>
PAT0350 - 0399 Apps<br/>
PAT2900 - 2999 ServiceCatalog<br/>

### Tags
Use Tags to enable sorting in the UI

### Assets
Connections: CON-xxxx-name<br/>
Credentials: CRE-xxxx-name<br/>
Variables: VAR-xxxx-name<br/>
Schedules: SCH-xxxx-name<br/>
xxxx = Four character abbreviation of the business domain or application<br/>
name = Variable name in camel case<br/>
