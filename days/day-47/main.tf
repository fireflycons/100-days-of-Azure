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
  description = "Name of the existing Azure resource group"
  type        = string
}

variable "azure_region" {
  description = "Azure region for deployed resources"
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "resource_suffix" {
  description = "Numeric suffix used in the SQL server and storage account names, such as 263123964."
  type        = number

  validation {
    condition     = var.resource_suffix > 0 && var.resource_suffix == floor(var.resource_suffix)
    error_message = "resource_suffix must be a positive whole number."
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  database_name        = "${var.infrastructure_prefix}-sqldb"
  server_name          = "${var.infrastructure_prefix}-server-${var.resource_suffix}"
  storage_account_name = "${var.infrastructure_prefix}st${var.resource_suffix}"
  primary_container    = "${var.infrastructure_prefix}-container-${var.resource_suffix}"
  backup_container     = "${var.infrastructure_prefix}-container-${var.resource_suffix}"
  backup_blob_name     = "${var.infrastructure_prefix}-db-backup.bacpac"
  backup_blob_uri      = "https://${azurerm_storage_account.this.name}.blob.core.windows.net/${azurerm_storage_container.backup.name}/${local.backup_blob_name}"
  downloaded_backup    = "/opt/${local.backup_blob_name}"
  sql_admin_username   = "${var.infrastructure_prefix}-admin"
}

resource "random_password" "sql_admin" {
  length           = 32
  special          = true
  override_special = "_-!@#$%"
}

resource "azurerm_mssql_server" "this" {
  name                          = local.server_name
  resource_group_name           = data.azurerm_resource_group.this.name
  location                      = var.azure_region
  version                       = "12.0"
  administrator_login           = local.sql_admin_username
  administrator_login_password  = random_password.sql_admin.result
  public_network_access_enabled = true
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "this" {
  name                 = local.database_name
  server_id            = azurerm_mssql_server.this.id
  sku_name             = "Basic"
  max_size_gb          = 2
  storage_account_type = "Local"
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "primary" {
  name               = local.primary_container
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_storage_container" "backup" {
  name               = local.backup_container
  storage_account_id = azurerm_storage_account.this.id
}

resource "terraform_data" "export_and_download" {
  depends_on = [azurerm_mssql_firewall_rule.allow_azure_services]

  triggers_replace = [
    azurerm_mssql_database.this.id,
    azurerm_storage_container.backup.id,
    local.backup_blob_name,
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -eu

      az sql db export \
        --admin-password '${random_password.sql_admin.result}' \
        --admin-user '${local.sql_admin_username}' \
        --auth-type SQL \
        --name '${azurerm_mssql_database.this.name}' \
        --resource-group '${data.azurerm_resource_group.this.name}' \
        --server '${azurerm_mssql_server.this.name}' \
        --storage-key '${azurerm_storage_account.this.primary_access_key}' \
        --storage-key-type StorageAccessKey \
        --storage-uri '${local.backup_blob_uri}'

      mkdir -p /opt
      az storage blob download \
        --account-name '${azurerm_storage_account.this.name}' \
        --account-key '${azurerm_storage_account.this.primary_access_key}' \
        --container-name '${azurerm_storage_container.backup.name}' \
        --name '${local.backup_blob_name}' \
        --file '${local.downloaded_backup}' \
        --overwrite true
    EOT
  }
}

output "sql_server_name" {
  description = "Azure SQL logical server name."
  value       = azurerm_mssql_server.this.name
}

output "sql_database_name" {
  description = "Azure SQL database name."
  value       = azurerm_mssql_database.this.name
}

output "backup_container_name" {
  description = "Container holding the exported BACPAC."
  value       = azurerm_storage_container.backup.name
}

output "backup_blob_uri" {
  description = "Blob URI for the exported BACPAC."
  value       = local.backup_blob_uri
}

output "downloaded_backup_path" {
  description = "Linux client path containing the downloaded BACPAC."
  value       = local.downloaded_backup
}