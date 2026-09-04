# KodeKloud 100 Days of Cloud - Azure (using terraform)

This repo contains terraform solutions to all the tasks where infrastructure needs to be deployed. It does *not* contain solutions to additional tasks that might be required after the infrastructure is deployed, if those tasks cannot be done from terraform.

Where days are missing are for tasks, then they either cannot be done using terraform, there is no cloud infrastructure to be deployed, or the question states to use the CLI or console for all steps.

For complete solutions you can refer to other peoples repos such as https://github.com/Srikanth0824/kodekloud-engineer/tree/main/100_Days_of_Cloud-Azure

## Install terraform on the lab terminal

For each lab, paste and run these commands into the lab terminal to set up terraform.

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
- [Day 24](days/day-24) - Securing Virtual Machine SSH Access
- [Day 25](days/day-25) - Expanding and Managing Disk Storage
- [Day 26](days/day-26) - Deploying Virtual Machines in a Public Virtual Network
- [Day 27](days/day-27) - Deploying Virtual Machines in a Private Virtual Network
- [Day 29](days/day-29) - Working with Azure Container Registry (ACR)
- [Day 30](days/day-30) - Create Azure SQL Database
- [Day 31](days/day-31) - Deploying and Managing a Web Application
- [Day 32](days/day-32) - Synchronizing Containers Using the CLI

## Note on solution implementation

For some of these tasks the `azure/azapi` provider is used for patching live resources pulled into the configuration as data sources. In real production use, this is a *Very Bad Idea*. Resources should be fully owned by terraform or not owned at all (in which case immutable). Normally for pre-existing resources you would `terraform import` them such that they become fully owned.

## Workstation configuration

All these solutions should be run in the KK lab terminal for ease, but should you want to clone the repo to your own laptop and run if from there, you need to set a few things up.

### Prerequisites

* `terraform` installed

### Environment variables

When you start a lab, you need to export 5 environment variables.

Paste these commands into the KKE lab terminal and run them to retrieve the required values

```bash
CREDS_FILE="/opt/creds.json"
CLIENT_ID=$(jq -r '."Azure Application Client ID"' "$CREDS_FILE")
CLIENT_SECRET=$(jq -r '."Azure Client Secret"' "$CREDS_FILE")
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
TENANT_ID=$(az account show --query "tenantId" --output tsv)

# Display table
echo
echo "Here are the values you need:"
echo
printf '%-22s %s\n' "Client ID:"             "$CLIENT_ID"
printf '%-22s %s\n' "Client Secret:"         "$CLIENT_SECRET"
printf '%-22s %s\n' "Subscription ID:"       "$SUBSCRIPTION_ID"
printf '%-22s %s\n' "Tenant ID:"             "$TENANT_ID"
printf '%-22s %s\n' "Resource Group Name:"   "$RESOURCE_GROUP_NAME"
```

First retrieve the values you need to set from the output of the above commands, then set up the environment variables in the shell you are working in on your laptop, using the values you obtained above:

**bash/zsh (Linux/Mac)**

```bash
export ARM_CLIENT_ID="replace-with-client-id"
export ARM_CLIENT_SECRET="replace-with-client-secret"
export ARM_TENANT_ID="replace-with-tenant-id"
export ARM_SUBSCRIPTION_ID="replace-with-subscription-id"
export TF_VAR_resource_group_name="replace-with-resource-group-name"
```

**Windows PowerShell**

```powershell
$env:ARM_CLIENT_ID="replace-with-client-id"
$env:ARM_CLIENT_SECRET="replace-with-client-secret"
$env:ARM_TENANT_ID="replace-with-tenant-id"
$env:ARM_SUBSCRIPTION_ID="replace-with-subscription-id"
$env:TF_VAR_resource_group_name="replace-with-resource-group-name"
```






