# Task: Deploying Virtual Machines in a Public Virtual Network

The Nautilus DevOps Team has received a request from the Networking Team to set up a new public VNet to support a set of public-facing services. This VNet will host various resources that need to be accessible over the internet. As part of this setup, you need to ensure the VNet has public subnets with automatic public IP assignment for resources. Additionally, a new VM will be launched within this VNet to host public applications that require SSH access. This setup will enable the Networking Team to deploy and manage public-facing applications.

# Task Details

Create a public VNet named `devops-pub-vnet`, and a subnet named `devops-pub-subnet` under the same, make sure public IP is being auto-assigned to resources under this subnet. Further, create a VM named `devops-pub-vm` under this VNet. Make sure SSH port `22` open for this instance and accessible over the internet. Use the Azure portal to complete the task and ensure that SSH access is configured correctly.

Create the resources only in the `East US` region.
