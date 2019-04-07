# Subscription Naming
For the Subscription naming a combination of a name and a short code separated by a dash is suggested. The short code is used in the Resource naming outlined below. The name of the Subscription is not re-used in any form and therefore doesn't have to comply with any standards. Examples:<br/>
* Core-co
* Test-te
* Production-pr
<br/>

# Resource Naming
The following naming convention is applicable to all Resources in Azure unless otherwise defined in the following chapters. All names are in small letters, caps are never used as they are not supported by all Resource Types. 
* weu-te-llb-app1-01

| Code | Description |
| ------------- | ------------- |
| weu | Azure region code - if a Resource Type is not available in a certain Region, the Region where it's supposedly operated is used |
| te | Subscription code - this assumes that environments are separated in Subscriptions. Might have to adapt if multiple environments are hosted in same subscription, e.g. both de/te in de: weu-de-llb-app1de-01 / weu-de-llb-app1te-01 |
| llb | Type of resource (see below) |
| app1 | Name of resource, arbitrary length - this could be application or project name |
| 01 | Sequence number per type and name (if required) |
<br/>

**Resource Type Short Codes**<br/>
There is a three character short code for each Azure Resource Type, this helps identify the Resource Type in e.g. a CLI script. A link is added if special naming conventions are applied for a specific Resource Type.<br/>

| Code | Resource Type | Description and Examples |
| ------------- | ------------- | ------------- |
| Application Insights | ais | |
| Azure Automation | aut | weu-co-aut-prod-01 |	
| Azure Automation Hybrid Worker | n/a | weu-co-aut-prod01-hyb01 |
| Resource Group | rsg | weu-co-rsg-automation-01 |
| **App Services** | | |
| App Service Environment | ase | weu-co-ase-felportal-01 |
| App Service Plan | asp | weu-co-asp-felportal-01 |
| App Service | aps | weu-co-aps-felportal-01 - no inheritance from asp as aps can be moved to other asp |
| **Databases**| | |
| Azure Analysis Services | aas | |
| SQL Server | sdb| [SQL Server & Databases](#sql-server--databases) |
| SQL Database | sdb | [SQL Server & Databases](#sql-server--databases) |
| SQL Datawarehouse | sdb | [SQL Server & Databases](#sql-server--databases) |
| SQL Managed Instance | smi | Standard naming for server, free for databases |
| **Networking** | | |
| Load Balancer | llb | [Load Balancer](#Load-Balancer) |
| Network Interface | n/a | [VM, NIC, Managed Disk and Public IP](#VM-NIC-Managed-Disk-and-Public-IP) |
| Network Security Group | nsg | [Network Security Group](#Network-Security-Group) |
| Public IP Address | pub | [VM, NIC, Managed Disk and Public IP](#VM-NIC-Managed-Disk-and-Public-IP) |
| Route Table | rte | weu-de-rte-vnet01-01 - inherit VNET name |
| Subnet | sub | [VNET & Subnets](#VNET-&-Subnets) |
| VNET (Virtual Network) | vnt | [VNET & Subnets](#VNET-&-Subnets) |
| VNET Peering |  | [VNET Peering](#VNET-Peering) |
| VPN Gateway | vgw | Inherit VNET name |
| **Storage** | | |
| Storage Account | n/a | [Storage Accounts and Log Analytics](#Storage-Accounts-and-Log-Analytics) |
| Managed Disk | n/a | [VM, NIC, Managed Disk and Public IP](#VM-NIC-Managed-Disk-and-Public-IP) |
| Recovery Service Vault | rsv | weu-co-rsv-grsvault-01 - use GRS in name to define vault type |
| **Other** | | |
| Event Grid Domains | egd | weu-te-egd-egdomain-01 |
| Event Grid Subscriptions | egs | weu-te-egs-egsub-01 |
| Event Hub Topics | egt | weu-te-egt-egtopic-01 |
| Event Hub | evh | Instance inherits name space |
| Log Analytics | n/a | [Storage Accounts and Log Analytics](#Storage-Accounts-and-Log-Analytics) |
| Key Vault | key | [Key Vault](#Key-Vault) |
| Virtual Machine | n/a | [VM, NIC, Managed Disk and Public IP](#VM-NIC-Managed-Disk-and-Public-IP) |
<br/>

**Region Short Codes**<br/>
The three character short code for the Azure Regions might not be sufficient to easily name all available Azure Regions. It should however bee sufficient to name the subset of Regions used by an individual customer. 

| Short Code | Region |
| ------------- | ------------- |
| chn | Switzerland North |
| chw | Switzerland West |
| neu | North Europe |
| weu | West Europe |
| aaa | Generic Location not tied to a specific Region |
<br/>

### Storage Accounts and Log Analytics
Storage Accounts and Log Analytics instances need to comply with special naming conventions. In addition, the names need to be unique across all of Azure – not just within a single Subscription.
* cusweudeappx01p 

| Code | Description |
| ------------- | ------------- |
| cus | Customer shortcode |
| weu | Location (see above) |
| de | Subscription (see above) |
| appx | Name of resource, arbitrary length - this could be application or project name |
| 01 | Sequence number |
| s | Storage Account type s(standard)/p(premium) |
<br/>

### VNET & Subnets
The name of the VNET is used without a hyphen in the Subnet: 
* weu-te-vnet-01 -> weu-te-sub-vnet01-fe

The last part of the Subnet denotes the two letter Subnet name, which is also used in the NIC naming:<br/>
* fe = Frontend
* be = Backend
* mg = Management
<br/>
<img src="https://github.com/fbodmer/AzureGovernance/wiki/Naming-Vnet.png" width="200">

### VM, NIC, Managed Disk and Public IP
The following diagram depicts how the naming convention is applied in the context of all the Resources related to a VM.

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Naming-Vm.png" width="300">

The VM name identifies in which cloud the VM is running an what remoting protocol is required to login to the server.
* azw1234

| Code | Description |
| ------------- | ------------- |
| az| Location (az = Azure / op = on-premise) |
| w | Windows (u = Linux/Unix /  e = physical and others) |
| 9999 | 0000-9999 |
<br/>

**NIC Naming**<br/>
The NIC naming consists of the VM to which the NIC is attached as well as the short code of the Subnet.
* azw1234-fe-1

| Code | Description |
| ------------- | ------------- |
| azw1234 | Name of VM to which the NIC is connected |
| fe | Short code of Subnet to which the NIC is connected |
| 1 | 1-9 sequence number |
<br/>
 
**Public IP Naming - in connection with VM**<br/>
Public IP addresses attached to VMs are using the standard naming convention, the individual part of the name corresponds to the VM name.
* weu-te-pub-azw1234-01

| Code | Description |
| ------------- | ------------- |
| weu | Azure region code |
| te | Subscription code |
| pub | Public IP |
| azw1234 | Name of VM as used in NIC name |
| 01 | 1-9 sequence number |
<br/>

### Network Security Group
Network Security Groups inherit the name of the Subnet, they are not using a counter as there can’t be multiple NSG with the same name.<br/>
* weu-te-nsg-vnet01be

| Code | Description |
| ------------- | ------------- |
| weu | Azure region code |
| te | Subscription code |
| nsg | Short code for Network Security Group |
| vnet01be | Name of the Subnet to which the Network Security Group is attached |
<br/>

### VNET Peering
Both the source and target VNET names are included in the name. VNET peering has to be configured in both VNETs, the names are therefore mirrored.<br/>
* weu-co-per-vnt01-weutevnt01 / weu-te-per-vnt01-weucovnt01

| Code | Description |
| ------------- | ------------- |
| weu | Azure region code |
| te | Subscription code |
| per | Short code for VNET Peering |
| weutevnt01 | Target VNET name without hyphens |


### Load Balancer
In complex resource structures, the main Resource name is used as a prefix for all attached sub-resources:<br/>
* weu-de-llb-paloalto-01 -> weu-de-llb-paloalto-01-fep01
<br/>
<img src="https://github.com/fbodmer/AzureGovernance/wiki/Naming-Llb.png" width="500">


### SQL Server & Databases
Resources inherit the Resource Type from the parent Resources. This is to ensure that the dependency can be determined in the name:
* we-de-sdb-appxy-01 -> weu-de-sdb-appxy01-dba

<img src="https://github.com/fbodmer/AzureGovernance/wiki/Naming-Sql.png" width="300">

### Key Vault 
The Key Vault name must be universally unique, meaning in can be used once in all of Azure. The reason being that assets within a Key Vault are accessed via `https://{vault-name}.vault.azure.net`.
* weu-te-key-felkeyvault-01

| Code | Description |
| ------------- | ------------- |
| weu | Azure region code |
| te | Subscription code |
| key | Short code for Key Vault |
| felkeyvault | Customer short code and name of resource, arbitrary length |
| 01 | 01-99 sequence number |




