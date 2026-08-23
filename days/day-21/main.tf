terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
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

provider "local" {}

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
  description = "Name of the existing resource group"
  type        = string
}

locals {
  vm_location        = "southcentralus"
  vm_size            = "Standard_B1s"
  vm_image_publisher = "Canonical"
  vm_image_offer     = "ubuntu-24_04-lts"
  vm_image_sku       = "server-gen1"
  vm_image_version   = "latest"
  admin_username     = "azureuser"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  filename        = pathexpand("~/.ssh/id_rsa")
  content         = tls_private_key.vm_key.private_key_pem
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = pathexpand("~/.ssh/id_rsa.pub")
  content         = tls_private_key.vm_key.public_key_openssh
  file_permission = "0644"
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.vm_location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = "${var.infrastructure_prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.infrastructure_prefix}-nsg"
  location            = local.vm_location
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                  = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.infrastructure_prefix}-pip"
  location            = local.vm_location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "this" {
  name                = "${var.infrastructure_prefix}-nic"
  location            = local.vm_location
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.infrastructure_prefix}-vm"
  location            = local.vm_location
  resource_group_name = data.azurerm_resource_group.this.name
  size                = local.vm_size

  admin_username                  = local.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm_key.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.vm_image_publisher
    offer     = local.vm_image_offer
    sku       = local.vm_image_sku
    version   = local.vm_image_version
  }
}

output "vm_id" {
  description = "The ID of the created virtual machine"
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_public_ip" {
  description = "The static public IP address for SSH access"
  value       = azurerm_public_ip.this.ip_address
}

output "private_key_path" {
  description = "Path to the generated private SSH key"
  value       = local_sensitive_file.private_key.filename
}

output "public_key_path" {
  description = "Path to the generated public SSH key"
  value       = local_file.public_key.filename
}
