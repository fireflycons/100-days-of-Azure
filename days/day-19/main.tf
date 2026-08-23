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
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group"
  type        = string
}

variable "storage_account_suffix" {
  description = "Suffix of the existing storage account (e.g. st32007)"
  type        = string
}

variable "public_container_suffix" {
  description = "Suffix of the public blob container to make private (e.g. 31464)"
  type        = string
}

locals {
  storage_account_name = "${var.infrastructure_prefix}${var.storage_account_suffix}"
  public_container_name = "${var.infrastructure_prefix}-container-${var.public_container_suffix}"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "this" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azapi_update_resource" "public_container" {
  type        = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  resource_id = "${data.azurerm_storage_account.this.id}/blobServices/default/containers/${local.public_container_name}"

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}
