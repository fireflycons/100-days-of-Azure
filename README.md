# KodeKloud 100 Days of Cloud - Azure (using terraform)

This repo contains terraform solutions to all the tasks where infrastructure needs to be deployed. It does *not* contain solutions to additional tasks that might be required after the infrastructure is deployed, if those tasks cannot be done from terraform.

Where days are missing are for those tasks that either cannot be done using terraform, or the question states to use the CLI or console for all tasks.

For complete solutions you can refer to other peoples repos such as https://github.com/Srikanth0824/kodekloud-engineer/tree/main/100_Days_of_Cloud-Azure

## Install terraform on the lab terminal

For each lab, paste and run these commands into the lab terminal to set up terraform.

```bash
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/1.15.2/terraform_1.15.2_linux_amd64.zip
unzip terraform.zip
mv terraform /usr/local/bin/
export TF_VAR_resource_group_name="$RESOURCE_GROUP_NAME"
```

## Solutions

- [Day 01](days/day-01) - Create SSH Key Pair for Azure Virtual Machines
- [Day 02](days/day-02) - Create an Azure Virtual Machine
- [Day 04](days/day-04) - Create a Virtual Network (VNet) in Azure
- [Day 05](days/day-05) - Create a Virtual Network (IPv4) in Azure
- [Day 06](days/day-06) - Create a Subnet in Azure Virtual Network
- [Day 07](days/day-07) - Create a Public IP Address for Azure VM


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






