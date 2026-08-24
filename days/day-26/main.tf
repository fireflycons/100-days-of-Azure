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
  description = "Name of the existing resource group"
  type        = string
}

locals {
  location           = "eastus"
  vm_size            = "Standard_B1s"
  admin_username     = "azureuser"
  vm_image_publisher = "Canonical"
  vm_image_offer     = "ubuntu-24_04-lts"
  vm_image_sku       = "server-gen1"
  vm_image_version   = "latest"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_virtual_network" "public" {
  name                = "${var.infrastructure_prefix}-pub-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_subnet" "public" {
  name                 = "${var.infrastructure_prefix}-pub-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "public" {
  name                = "${var.infrastructure_prefix}-pub-nsg"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public" {
  name                = "${var.infrastructure_prefix}-pub-ip"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "public" {
  name                = "${var.infrastructure_prefix}-pub-nic"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "public-ip-config"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public.id
  }
}

resource "azurerm_network_interface_security_group_association" "public" {
  network_interface_id      = azurerm_network_interface.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_linux_virtual_machine" "public" {
  name                = "${var.infrastructure_prefix}-pub-vm"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  size                = local.vm_size

  admin_username                  = local.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm_key.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.public.id,
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

output "vnet_id" {
  description = "ID of the public virtual network"
  value       = azurerm_virtual_network.public.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = azurerm_subnet.public.id
}

output "vm_id" {
  description = "ID of the public virtual machine"
  value       = azurerm_linux_virtual_machine.public.id
}

output "vm_public_ip" {
  description = "Public IP address for SSH access"
  value       = azurerm_public_ip.public.ip_address
}

output "ssh_private_key" {
  description = "Generated private SSH key"
  value       = tls_private_key.vm_key.private_key_pem
  sensitive   = true
}
