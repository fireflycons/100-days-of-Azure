# Azure Provider Configuration
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
  type = string
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  vnet_name = "${var.infrastructure_prefix}-vnet"
  location  = "centralus"
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}
