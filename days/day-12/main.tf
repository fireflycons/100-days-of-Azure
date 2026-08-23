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

locals {
  virtual_machine_name = "${var.infrastructure_prefix}-vm"
  environment_tag      = "dev"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "this" {
  name                = local.virtual_machine_name
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azapi_update_resource" "this" {
  type        = "Microsoft.Compute/virtualMachines@2023-09-01"
  resource_id = data.azurerm_virtual_machine.this.id

  body = {
    tags = {
      Environment = local.environment_tag
    }
  }
}
