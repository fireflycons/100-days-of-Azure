terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

provider "azapi" {}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names."
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

variable "resource_group_name" {
  description = "Name of the existing Azure resource group."
  type        = string
}

variable "azure_region" {
  description = "Azure region for the storage account."
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "storage_account_suffix" {
  description = "Numeric suffix used for the storage account and container names."
  type        = number
}

locals {
  vm_name       = "${var.infrastructure_prefix}-vm"
  admin_user    = "azureuser"
  storage_name  = "${var.infrastructure_prefix}stor${var.storage_account_suffix}"
  container_name = "${var.infrastructure_prefix}-container${var.storage_account_suffix}"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "this" {
  name                = local.vm_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azapi_resource" "this" {
  type                   = "Microsoft.Compute/virtualMachines@2023-09-01"
  resource_id            = data.azurerm_virtual_machine.this.id
  response_export_values = ["properties.networkProfile.networkInterfaces"]
}

data "azurerm_network_interface" "this" {
  name = element(
    split(
      "/",
      data.azapi_resource.this.output.properties.networkProfile.networkInterfaces[0].id
    ),
    8
  )
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_public_ip" "this" {
  name = element(
    split("/", data.azurerm_network_interface.this.ip_configuration[0].public_ip_address_id),
    8
  )
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "this" {
  name                  = local.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "terraform_data" "upload_test_file" {
  triggers_replace = [
    azurerm_storage_container.this.id,
    data.azurerm_public_ip.this.ip_address,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-SHELL
      ssh -i ~/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${local.admin_user}@${data.azurerm_public_ip.this.ip_address}" "bash -s" <<'REMOTE_SCRIPT'
      set -eu
      printf '%s\n' 'this is a test file' > /home/azureuser/testfile.txt
      az storage blob upload \
        --account-name '${azurerm_storage_account.this.name}' \
        --account-key '${azurerm_storage_account.this.primary_access_key}' \
        --container-name '${azurerm_storage_container.this.name}' \
        --name testfile.txt \
        --file /home/azureuser/testfile.txt \
        --overwrite
      REMOTE_SCRIPT
    SHELL
  }
}