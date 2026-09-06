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
  description = "Prefix used for resource names."
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

variable "resource_group_name" {
  description = "Existing resource group containing the virtual networks."
  type        = string
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "public" {
  name                = "${var.infrastructure_prefix}-pub-vnet"
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_virtual_network" "private" {
  name                = "${var.infrastructure_prefix}-priv-vnet"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_virtual_network_peering" "public_to_private" {
  name                      = "${var.infrastructure_prefix}-pub-to-priv-peering"
  resource_group_name       = data.azurerm_resource_group.this.name
  virtual_network_name      = data.azurerm_virtual_network.public.name
  remote_virtual_network_id = data.azurerm_virtual_network.private.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "private_to_public" {
  name                      = "${var.infrastructure_prefix}-priv-to-pub-peering"
  resource_group_name       = data.azurerm_resource_group.this.name
  virtual_network_name      = data.azurerm_virtual_network.private.name
  remote_virtual_network_id = data.azurerm_virtual_network.public.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
