# Task: Deploying Virtual Machines in a Private Virtual Network

The Nautilus DevOps team is expanding their Azure infrastructure and requires the setup of a private Virtual Network (VNet) along with a subnet. This VNet and subnet configuration will ensure that resources deployed within them remain isolated from external networks and can only communicate within the VNet. Additionally, the team needs to provision a Virtual Machine (VM) under the newly created private VNet. This VM should be accessible over SSH from within the VNet only, allowing for secure communication and resource management within the Azure environment.

# Task Details

The name of the VNet must be `devops-priv-vnet`, create a subnet named `devops-priv-subnet` under the same. Further, create a Virtual Machine named `devops-priv-vm` under this VNet. Additionally, create a Network Security Group (NSG) named `devops-priv-nsg`, and ensure that the NSG rules for the VM allow access only from within the VNet's CIDR block. Ensure all resources are created in the Central US region.

* Create the resources only in the `Central US` region.
* Use the VNet CIDR `10.0.0.0/16` for `devops-priv-vnet` in `Central US`.
* Set up an explicit NSG inbound SSH rule on `devops-priv-nsg` with the following parameters:
    * Source: `10.0.0.0/16`
    * Destination: `10.0.0.0/16`
    * TCP Port: `22`
    * Action: `Allow`
