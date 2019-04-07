Below topics list the advantages and disadvantages of using VPN vs. ExpressRoute.

### SLA

Both VPN and ER require the deployment of a [VPN gateway, which supports an SLA of 99.9% or 99.95%](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fazure.microsoft.com%2Fen-us%2Fsupport%2Flegal%2Fsla%2Fvpn-gateway%2Fv1_3%2F&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=I0VGWeCnl03vJw%2BRzo68vq%2BjN5kCm1gj9PonG5jYgsk%3D&amp;reserved=0) depending on the SKU. In case of VPN connections there is no additional SLA as the components (network, remote gateway) are not operated by Microsoft. For ER there is a [99.95% dedicated circuit availability SLA](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fazure.microsoft.com%2Fen-us%2Fsupport%2Flegal%2Fsla%2Fexpressroute%2Fv1_3%2F&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=IUInPF3ZYfplkbqKn%2BZvt9nw1HcDZwyfoJnd4gm0mds%3D&amp;reserved=0).
The release of [active-active site-to-site VPN connections](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-highlyavailable) increased the availability of VPN links.

### Bandwidth

[VPN offers bandwidth of up to 1.25 Gbps](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fazure.microsoft.com%2Fen-us%2Fpricing%2Fdetails%2Fvpn-gateway%2F&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=p9LfJfCSI5mTEsSuoj%2BrWHrSBrn3J0iK6WDkuIS3CSk%3D&amp;reserved=0) while [ER offers speeds of up to 10 Gbps](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-introduction#bandwidth-options).

### Link quality

From a technical point of view, one could argue that the link quality using ER is superior to VPN. However, VPN are an established technology, widely used by customers. Based on their experience with existing VPN, customers know best about the expected VPN link quality.

### Latency

From a technology point of view ER offers better and more consistent latency than VPN. While the consistency of the latency is likely better with ER, the latency depends on the network architecture. With VPN, more fine-grained connectivity to Azure might be achieved, which also has an impact on latency. In any case, the latency is likely more dependent on the geographical location of the user community than the choice between ER and VPN.

### Setup

The setup of ER is considerably more complex than the setup of VPN. One of the main reasons for the added complexity is the requirement to involve third parties in the setup process. While the provisioning of a VPN can be achieved in hours, days or weeks are required for ER.

### Manageability

In a VPN environment, operational issues can be handled by customers. With ER the involvement of Microsoft and possibly a third-party carrier is required. In a worst-case scenario, a new/additional VPN can be provisioned, this is not possible using ER.
Using ER, customers are dependent on the BGP routes published by Microsoft. Changes in these published routes (as happened before) can have an impact on established routing patterns. There is little or no control as to what BGP routes are announced by Microsoft.

### Encryption &amp; Traffic routing

While VPN can be natively encrypted, this is not an option on ER. On the other hand, ER is using dedicated links and is not traversing the Internet as is the case with VPN. As all traffic to and from Azure should be encrypted, this is neither an advantage or disadvantage for either technology.

### Pricing

Both VPN and ER require the deployment of a [VPN Gateway which is priced by hour of operation](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fazure.microsoft.com%2Fen-us%2Fpricing%2Fdetails%2Fvpn-gateway%2F&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=p9LfJfCSI5mTEsSuoj%2BrWHrSBrn3J0iK6WDkuIS3CSk%3D&amp;reserved=0). In addition, ER offers a [metered or unlimited data plan](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fazure.microsoft.com%2Fen-us%2Fpricing%2Fdetails%2Fexpressroute%2F&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=rotacFk30SoLS9BPFQKygJvdWdN5uj5HNbnUVjsifQ4%3D&amp;reserved=0), with an optional ER Premium add-on. This add-on raises some technical limits but most important allows for global connectivity. This means an ER circuit created in one Azure Region can be used in any other Azure Region. The benefits of ER Premium needs to be weighed against the used of VNET Peering (see below).

### Connectivity options

There are multiple options on how to implement connectivity between VNETs in Azure and to on-premise data centers. VNET Peering within and across Azure regions can be combined with VPN and ER connections. One distinct advantage of ER is the possibility of using the Microsoft network as a backbone for intra/inter regional traffic. This option is available for any type of traffic pattern – Azure internal, on-premise internal, between Azure and on-premise.

### Dependency on Subscriptions, AD Tenants and enrollment

VPNs are configurable in a single subscription for a single VNET only. ER on the other hand can span Subscriptions, AD Tenants and EA enrollment boundaries. In other words, a single ER link can be attached to any VNET independent of the location of the VNET with regards to Subscription, AD Tenant and EA enrollment.

### IaaS vs. PaaS

VPN based connectivity is limited to VNETs and with that IaaS, with the exception of (the few) PaaS that can be configured using [Virtual Network integration](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fdocs.microsoft.com%2Fen-us%2Fazure%2Fvirtual-network%2Fvirtual-network-for-azure-services&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=8wHQbPOicEnQHMlqzvEKTP4DKPbKeXg86x16F%2FKclTg%3D&amp;reserved=0). ER route offers connectivity not only to VNETs [(Private Peering) but also to PaaS and other Microsoft Cloud services (Microsoft Peering)](https://na01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fdocs.microsoft.com%2Fen-us%2Fazure%2Fexpressroute%2Fexpressroute-circuit-peerings&amp;data=02%7C01%7Cv-febodm%40microsoft.com%7Cd3712a7a3f8042ed6b3408d568ab2479%7Cee3303d7fb734b0c8589bcd847f1c277%7C1%7C0%7C636530006632471878&amp;sdata=ybXvwxuKVKKk5mWulovUJBElCKb66PCW30lrpS0a2aY%3D&amp;reserved=0). The advantage of ER is that PaaS services can be access via a private link and never traverse the Internet – advantages/disadvantages with regards to latency, cost etc. are outlined above.

### Traffic Shaping

ER offers QoS on Microsoft Peering for Skype Voice calls, no other QoS is available for ER. There is not QoS on VPN connections. Any traffic shaping and/or cost distribution needs to be implemented using third party virtual appliances.