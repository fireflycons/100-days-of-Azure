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
  description = "Name of the existing Azure resource group."
  type        = string
}

variable "azure_region" {
  description = "Azure region for the storage account."
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "storage_suffix" {
  description = "Numeric suffix used for the storage account name, such as 7199."
  type        = number

  validation {
    condition     = var.storage_suffix > 0 && var.storage_suffix == floor(var.storage_suffix)
    error_message = "storage_suffix must be a positive whole number."
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  storage_account_name = "${var.infrastructure_prefix}tablest${var.storage_suffix}"
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_table" "tasks" {
  name               = "tasks"
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_storage_table_entity" "task_1" {
  storage_table_id = azurerm_storage_table.tasks.id
  partition_key    = "tasks"
  row_key          = "1"

  entity = {
    description = "Learn Table Storage"
    status      = "completed"
  }
}

resource "azurerm_storage_table_entity" "task_2" {
  storage_table_id = azurerm_storage_table.tasks.id
  partition_key    = "tasks"
  row_key          = "2"

  entity = {
    description = "Build To-Do App"
    status      = "in-progress"
  }
}

output "storage_account_name" {
  description = "Name of the Table Storage account."
  value       = azurerm_storage_account.this.name
}

output "table_name" {
  description = "Name of the task table."
  value       = azurerm_storage_table.tasks.name
}
