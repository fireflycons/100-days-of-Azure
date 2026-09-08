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

variable "storage_account_suffix" {
  description = "Numeric suffix used for the storage account name."
  type        = number
}

locals {
  storage_account_name = "${var.infrastructure_prefix}webst${var.storage_account_suffix}"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account_static_website" "this" {
  storage_account_id = azurerm_storage_account.this.id
  index_document     = "index.html"
}

resource "azurerm_storage_blob" "index" {
  name                 = "index.html"
  storage_container_id = "${azurerm_storage_account_static_website.this.id}/blobServices/default/containers/$web"
  type                 = "Block"
  source               = "${path.module}/index.html"
  content_type         = "text/html"
}

output "primary_web_endpoint" {
  description = "Primary endpoint URL for the static website."
  value       = azurerm_storage_account.this.primary_web_endpoint
}