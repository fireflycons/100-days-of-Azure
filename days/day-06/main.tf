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

locals {
  vnet_name        = "${var.infrastructure_prefix}-vnet"
  subnet_name      = "${var.infrastructure_prefix}-subnet"
  location         = "southcentralus"
  address_space    = ["10.0.0.0/16"]
  subnet_range     = ["10.0.1.0/24"]
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  address_space       = local.address_space
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = local.subnet_name
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = local.subnet_range
}
