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

locals {
  network_interface_name      = "${var.infrastructure_prefix}-vmVMNic"
  blocking_outbound_rule_name = "Block-All-Outbound"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_network_interface" "vm" {
  name                = local.network_interface_name
  resource_group_name = data.azurerm_resource_group.this.name
}
locals {
  network_security_group_name = element(split("/", data.azurerm_network_interface.vm.network_security_group_id), length(split("/", data.azurerm_network_interface.vm.network_security_group_id)) - 1)
}

resource "terraform_data" "remove_blocking_outbound_rule" {
  triggers_replace = [data.azurerm_network_interface.vm.network_security_group_id]

  provisioner "local-exec" {
    command = "az network nsg rule delete --resource-group ${data.azurerm_resource_group.this.name} --nsg-name ${local.network_security_group_name} --name ${local.blocking_outbound_rule_name}"
  }
}
