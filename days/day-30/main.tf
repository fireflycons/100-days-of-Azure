terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
  description = "Name of the existing resource group"
  type        = string
}

variable "server_name_suffix" {
  description = "Suffix appended to the Azure SQL server name (e.g. 2353)"
  type        = string
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location       = "West US"
  database_name  = "${var.infrastructure_prefix}-sqldb"
  server_name    = "${var.infrastructure_prefix}-server-${var.server_name_suffix}"
  admin_username = "${var.infrastructure_prefix}-admin"
}

resource "random_password" "sql_admin" {
  length           = 32
  special          = true
  override_special = "_-!@#$%"
}

resource "azurerm_mssql_server" "this" {
  name                         = local.server_name
  resource_group_name          = data.azurerm_resource_group.this.name
  location                     = local.location
  version                      = "12.0"
  administrator_login          = local.admin_username
  administrator_login_password = random_password.sql_admin.result
}

resource "azurerm_mssql_database" "this" {
  name                 = local.database_name
  server_id            = azurerm_mssql_server.this.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  sku_name             = "Basic"
  max_size_gb          = 2
  storage_account_type  = "Local"
}

output "server_name" {
  description = "Azure SQL logical server name"
  value       = azurerm_mssql_server.this.name
}

output "database_name" {
  description = "Azure SQL database name"
  value       = azurerm_mssql_database.this.name
}
