terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
  }
}

provider "azapi" {}

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
  location     = "southcentralus"
  ssh_key_name = "${var.infrastructure_prefix}-kp"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azapi_resource" "ssh_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2023-09-01"
  name      = local.ssh_key_name
  parent_id = data.azurerm_resource_group.this.id
  location  = local.location

  body = {
    properties = {}
  }
}

resource "azapi_resource_action" "generate_key_pair" {
  type                   = "Microsoft.Compute/sshPublicKeys@2023-09-01"
  resource_id            = azapi_resource.ssh_key.id
  action                 = "generateKeyPair"
  method                 = "POST"
  response_export_values = ["*"]
}

output "ssh_public_key_id" {
  description = "The Azure resource ID of the generated SSH key pair"
  value       = azapi_resource.ssh_key.id
}
