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

variable "storage_account_suffix" {
  description = "Suffix appended to the storage account name"
  type        = string
}

variable "source_container_suffix" {
  description = "Suffix appended to the source container name"
  type        = string
}

variable "destination_container_suffix" {
  description = "Suffix appended to the destination container name"
  type        = string
}

locals {
  storage_account_name       = "${var.infrastructure_prefix}${var.storage_account_suffix}"
  source_container_name      = "${var.infrastructure_prefix}-source-${var.source_container_suffix}"
  destination_container_name = "${var.infrastructure_prefix}-dest-${var.destination_container_suffix}"
  blob_name                  = "${var.infrastructure_prefix}.txt"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "source" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_storage_container" "destination" {
  name                  = local.destination_container_name
  storage_account_id    = data.azurerm_storage_account.source.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "migration" {
  name                 = local.blob_name
  storage_container_id = azurerm_storage_container.destination.id
  type                 = "Block"
  source_uri           = "${data.azurerm_storage_account.source.primary_blob_endpoint}${local.source_container_name}/${local.blob_name}"
}

output "source_blob_uri" {
  value = "${data.azurerm_storage_account.source.primary_blob_endpoint}${local.source_container_name}/${local.blob_name}"
}

output "destination_blob_uri" {
  value = "${data.azurerm_storage_account.source.primary_blob_endpoint}${local.destination_container_name}/${local.blob_name}"
}