terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

provider "tls" {}

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

variable "storage_account_suffix" {
  description = "Numeric suffix used for the storage account and backup container, such as 13765."
  type        = number

  validation {
    condition     = var.storage_account_suffix > 0 && var.storage_account_suffix == floor(var.storage_account_suffix)
    error_message = "storage_account_suffix must be a positive whole number."
  }
}

variable "send_logs_path" {
  description = "Path to send_logs.py. By default, the file is read from this configuration directory."
  type        = string
  default     = "send_logs.py"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  vm_admin_username = "azureuser"
  send_logs_file    = abspath("${path.module}/${var.send_logs_path}")
  rendered_script = replace(
    replace(
      file(local.send_logs_file),
      "<Event Hub Connection String>",
      azurerm_eventhub_authorization_rule.send_logs.primary_connection_string,
    ),
    "<Blob Storage Connection String>",
    azurerm_storage_account.this.primary_connection_string,
  )
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_eventhub_namespace" "this" {
  name                = "${var.infrastructure_prefix}-namespace"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"

  auto_inflate_enabled     = true
  maximum_throughput_units = 10
}

resource "azurerm_eventhub" "this" {
  name              = "${var.infrastructure_prefix}-hub"
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = 2
  message_retention = 1
}

resource "azurerm_eventhub_authorization_rule" "send_logs" {
  name                = "${var.infrastructure_prefix}-send-logs"
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this.name
  resource_group_name = data.azurerm_resource_group.this.name
  listen              = false
  send                = true
  manage              = false
}

resource "azurerm_storage_account" "this" {
  name                            = "${var.infrastructure_prefix}st${var.storage_account_suffix}"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = var.azure_region
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true
}

resource "azurerm_storage_container" "backup" {
  name                  = "${var.infrastructure_prefix}-backup-${var.storage_account_suffix}"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "blob"
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.46.0.0/16"]
}

resource "azurerm_subnet" "this" {
  name                 = "${var.infrastructure_prefix}-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.46.0.0/24"]
}

resource "azurerm_public_ip" "vm" {
  name                = "${var.infrastructure_prefix}-vm-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.infrastructure_prefix}-vm-nic"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.infrastructure_prefix}-vm"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  size                = "Standard_B1s"

  admin_username                  = local.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]

  admin_ssh_key {
    username   = local.vm_admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-CLOUD_INIT
    #!/bin/bash
    set -eu

    apt-get update
    apt-get install --yes python3-venv
    python3 -m venv /home/azureuser/.send-logs-venv
    /home/azureuser/.send-logs-venv/bin/pip install azure-eventhub azure-storage-blob

    cat > /home/azureuser/send_logs.py <<'PYTHON'
    ${local.rendered_script}
    PYTHON
    chown azureuser:azureuser /home/azureuser/send_logs.py

    for run_number in 1 2 3 4 5; do
      /home/azureuser/.send-logs-venv/bin/python /home/azureuser/send_logs.py
    done
  CLOUD_INIT
  )
}

output "eventhub_namespace_name" {
  description = "Name of the Event Hubs namespace."
  value       = azurerm_eventhub_namespace.this.name
}

output "eventhub_name" {
  description = "Name of the Event Hub."
  value       = azurerm_eventhub.this.name
}

output "storage_account_name" {
  description = "Name of the log backup storage account."
  value       = azurerm_storage_account.this.name
}

output "backup_container_name" {
  description = "Name of the public log backup container."
  value       = azurerm_storage_container.backup.name
}

output "vm_public_ip" {
  description = "Public IP address of the log sender VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "ssh_private_key" {
  description = "Generated SSH private key for the VM."
  value       = tls_private_key.vm.private_key_pem
  sensitive   = true
}