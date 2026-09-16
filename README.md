# KodeKloud 100 Days of Cloud - Azure (using terraform)

This repo contains terraform solutions to all the tasks where infrastructure needs to be deployed. It does *not* contain solutions to additional tasks that might be required after the infrastructure is deployed, if those tasks cannot be done from terraform.

Where days are missing are for tasks, then they either cannot be done using terraform, there is no cloud infrastructure to be deployed, or the question states to use the CLI or console for all steps.

For complete solutions you can refer to other peoples repos such as https://github.com/Srikanth0824/kodekloud-engineer/tree/main/100_Days_of_Cloud-Azure

## Install terraform on the lab terminal

For each lab, paste and run these commands into the lab terminal to set up terraform, and to create environment variables for Azure interaction. All configurations use the resource group name and some of them require some or all of the authentication variables.

```bash
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/1.15.2/terraform_1.15.2_linux_amd64.zip
unzip terraform.zip
mv terraform /usr/local/bin/
export TF_VAR_resource_group_name="$RESOURCE_GROUP_NAME"
export TF_VAR_client_id=$(jq -r '."Azure Application Client ID"' /opt/creds.json)
export TF_VAR_client_secret=$(jq -r '."Azure Client Secret"' /opt/creds.json)
export TF_VAR_subscription_id=$(jq -r '.subscriptions[] | select(.isDefault == true) | .id' ~/.azure/azureProfile.json)
export TF_VAR_tenant_id=$(jq -r '.subscriptions[] | select(.isDefault == true) | .tenantId' ~/.azure/azureProfile.json)

```

## Solutions

- [Day 01](days/day-01) - Create SSH Key Pair for Azure Virtual Machines
- [Day 02](days/day-02) - Create an Azure Virtual Machine
- [Day 04](days/day-04) - Create a Virtual Network (VNet) in Azure
- [Day 05](days/day-05) - Create a Virtual Network (IPv4) in Azure
- [Day 06](days/day-06) - Create a Subnet in Azure Virtual Network
- [Day 07](days/day-07) - Create a Public IP Address for Azure VM
- [Day 08](days/day-08) - Attach Managed Disk to Azure Virtual Machine
- [Day 09](days/day-09) - Attach Network Interface Card (NIC) to Azure Virtual Machine
- [Day 10](days/day-10) - Attach Public IP to Azure Virtual Machine
- [Day 12](days/day-12) - Add and Manage Tags for Azure Virtual Machines
- [Day 14](days/day-14) - Create and Attach Managed Disks in Azure
- [Day 15](days/day-15) - Create and Configure Network Security Group (NSG) in Azure
- [Day 16](days/day-16) - Create a Private Azure Blob Storage Container
- [Day 17](days/day-17) - Create a Public Azure Blob Storage Container
- [Day 19](days/day-19) - Convert Public Azure Blob Container to Private
- [Day 21](days/day-21) - Assigning Public IP to Virtual Machines
- [Day 22](days/day-22) - Configuring Instances with User Data
- [Day 23](days/day-23) - Automating User Data Configuration
- [Day 24](days/day-24) - Securing Virtual Machine SSH Access
- [Day 25](days/day-25) - Expanding and Managing Disk Storage
- [Day 26](days/day-26) - Deploying Virtual Machines in a Public Virtual Network
- [Day 27](days/day-27) - Deploying Virtual Machines in a Private Virtual Network
- [Day 29](days/day-29) - Working with Azure Container Registry (ACR)
- [Day 30](days/day-30) - Create Azure SQL Database
- [Day 31](days/day-31) - Deploying and Managing a Web Application
- [Day 32](days/day-32) - Synchronizing Containers
- [Day 33](days/day-33) - Integrating Virtual Machines with Application Load Balancer
- [Day 34](days/day-34) - Enabling Internet Connectivity for Virtual Machines
- [Day 35](days/day-35) - Configuring Virtual Network Peering
- [Day 36](days/day-36) - Managing Storage Lifecycle in Azure
- [Day 37](days/day-37) - Setting Up MySQL on a Virtual Machine in Azure
- [Day 38](days/day-38) - Running Containers on Azure Virtual Machines
- [Day 39](days/day-39) - Deploying a Static Website Using Containers on Azure
- [Day 40](days/day-40) - Managing Secrets with Azure Key Vault
- [Day 41](days/day-41) - Working with Azure Table Storage
- [Day 42](days/day-42) - Backup and Delete Azure Storage Blob Container
- [Day 43](days/day-43) - Configuring Azure VM with Application Gateway
- [Day 44](days/day-44) - Integrating Azure Event Hub with Virtual Machines
- [Day 45](days/day-45) - Azure Kubernetes Service (AKS) Setup and Management
- [Day 46](days/day-46) - EventHub to Blob Storage Integration Setup
- [Day 47](days/day-47) - SQL Database Migration and Setup
- [Day 48](days/day-48) - VM and ACR Integration for Storage
- [Day 49](days/day-49) - VM Setup with Web Storage Integration
- [Day 50](days/day-50) - VM Setup and Configuration for Azure Application Gateway

## Note on solution implementation

For some of these tasks the `azure/azapi` provider is used for patching live resources pulled into the configuration as data sources. In real production use, this is a *Very Bad Idea*. Resources should be fully owned by terraform or not owned at all (in which case immutable). Normally for pre-existing resources you would `terraform import` them such that they become fully owned.

For other tasks where an already existing machine needs to be configured by executing commands on it, the `local-exec` provisioner is used to run remote commands over SSH. This is also not seen as good practice in production. Ideally infrastructure should be immutable, meaning that all configuration is done by custom data/userdata scripts when a VM is first deployed, either that or pre-burned into a custom machine image. For reconfiguration of VMs that are already running, Ansible would be the better choice.

