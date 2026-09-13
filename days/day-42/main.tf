terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

variable "resource_group_name" {
  description = "Name of the existing Azure resource group"
  type        = string
}

variable "azure_region" {
  description = "Azure region for deployed resources"
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "storage_account_suffix" {
  description = "Numeric suffix used for the existing storage account and blob container, such as 428691458."
  type        = number

  validation {
    condition     = var.storage_account_suffix > 0 && var.storage_account_suffix == floor(var.storage_account_suffix)
    error_message = "storage_account_suffix must be a positive whole number."
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "this" {
  name                = "${var.infrastructure_prefix}st${var.storage_account_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
}

locals {
  container_name = "${var.infrastructure_prefix}-blob-${var.storage_account_suffix}"
}

resource "terraform_data" "backup_and_delete_container" {
  triggers_replace = [
    data.azurerm_storage_account.this.id,
    local.container_name,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eu

      mkdir -p /opt
      az storage blob download-batch \
        --account-name '${data.azurerm_storage_account.this.name}' \
        --account-key '${data.azurerm_storage_account.this.primary_access_key}' \
        --source '${local.container_name}' \
        --destination /opt \
        --overwrite true

      az storage container delete \
        --account-name '${data.azurerm_storage_account.this.name}' \
        --account-key '${data.azurerm_storage_account.this.primary_access_key}' \
        --name '${local.container_name}'
    EOT
  }
}

output "storage_account_name" {
  description = "Name of the backed-up storage account."
  value       = data.azurerm_storage_account.this.name
}

output "container_name" {
  description = "Name of the backed-up and deleted blob container."
  value       = local.container_name
}

output "backup_directory" {
  description = "Directory containing the downloaded blob contents."
  value       = "/opt"
}