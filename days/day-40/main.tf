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
  description = "Azure region for the Key Vault."
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "vault_suffix" {
  description = "Numeric suffix used for the Key Vault name."
  type        = number

  validation {
    condition     = var.vault_suffix > 0 && var.vault_suffix == floor(var.vault_suffix)
    error_message = "vault_suffix must be a positive whole number."
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

locals {
  key_vault_name = "${var.infrastructure_prefix}-${var.vault_suffix}"
  key_name       = "${var.infrastructure_prefix}-key"
}

resource "azurerm_key_vault" "this" {
  name                       = local.key_vault_name
  location                   = var.azure_region
  resource_group_name        = data.azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = false
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "Create",
      "Encrypt",
      "Decrypt",
      "GetRotationPolicy",
    ]
  }
}

resource "azurerm_key_vault_key" "this" {
  name         = local.key_name
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["encrypt", "decrypt"]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -eu

      echo "Encrypt:"
      source_file="/root/SensitiveData.txt"
      encrypted_file="/root/EncryptedData.bin"
      decrypted_file="/root/DecryptedData.txt"
      plaintext_b64=$(base64 "$source_file")
      ciphertext_b64=$(az keyvault key encrypt \
        --vault-name "${local.key_vault_name}" \
        --name "${local.key_name}" \
        --algorithm RSA-OAEP \
        --value "$plaintext_b64" \
        --query result \
        --output tsv > EncryptedData.b64)
      base64 -d /root/EncryptedData.b64 > "$encrypted_file"

      echo
      echo "Decrypt:"
      encrypted_b64=$(cat /root/EncryptedData.b64)
      az keyvault key decrypt \
        --vault-name "${local.key_vault_name}" \
        --name "${local.key_name}" \
        --algorithm RSA-OAEP \
        --value "$encrypted_b64" \
        --query result \
        --output tsv | base64 --decode > "$decrypted_file"

      cmp -- "$source_file" "$decrypted_file"
      rm -f -- "$decrypted_file"
    EOT
  }
}

output "key_vault_name" {
  description = "Name of the Key Vault containing the encryption key."
  value       = azurerm_key_vault.this.name
}

output "key_name" {
  description = "Name of the symmetric encryption key."
  value       = azurerm_key_vault_key.this.name
}
