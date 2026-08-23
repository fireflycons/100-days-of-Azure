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
  description = "Name of the existing resource group"
  type        = string
}

locals {
  managed_disk_name = "${var.infrastructure_prefix}-disk"
  disk_size_gb      = 2
  storage_type      = "Standard_LRS"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_managed_disk" "this" {
  name                 = local.managed_disk_name
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  storage_account_type = local.storage_type
  disk_size_gb         = local.disk_size_gb
  create_option        = "Empty"
}