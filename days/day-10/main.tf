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
  public_ip_name  = "${var.infrastructure_prefix}-pip"
  virtual_machine = "${var.infrastructure_prefix}-vm-pip"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "this" {
  name                = local.virtual_machine
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_public_ip" "this" {
  name                = local.public_ip_name
  resource_group_name = data.azurerm_resource_group.this.name
}


data "azapi_resource" "virtual_machine" {
  type                   = "Microsoft.Compute/virtualMachines@2023-09-01"
  resource_id            = data.azurerm_virtual_machine.this.id
  response_export_values = ["properties.networkProfile.networkInterfaces"]
}

data "azurerm_network_interface" "this" {
  name = element(
    split(
      "/",
      data.azapi_resource.virtual_machine.output.properties.networkProfile.networkInterfaces[0].id
    ),
    8
  )
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azapi_update_resource" "this" {
  type        = "Microsoft.Network/networkInterfaces@2023-09-01"
  resource_id = data.azurerm_network_interface.this.id

  body = {
    properties = {
      ipConfigurations = [
        {
          name = data.azurerm_network_interface.this.ip_configuration[0].name
          properties = {
            publicIPAddress = {
              id = data.azurerm_public_ip.this.id
            }
          }
        }
      ]
    }
  }
}