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
  vm_name   = "${var.infrastructure_prefix}-vm"
  disk_name = "${var.infrastructure_prefix}-disk"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "this" {
  name                = local.vm_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_managed_disk" "this" {
  name                = local.disk_name
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  managed_disk_id    = data.azurerm_managed_disk.this.id
  virtual_machine_id = data.azurerm_virtual_machine.this.id
  lun                = 0
  caching            = "ReadWrite"
}