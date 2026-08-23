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

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

variable "blob_container_name" {
  description = "Name of the blob container"
  type        = string
  validation {
    condition     = length(var.blob_container_name) <= 63
    error_message = "Blob container name must be 63 characters or less."
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = data.azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "blob" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}
