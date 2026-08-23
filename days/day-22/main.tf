terraform {
  required_version = ">= 1.5.0"

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
  location          = "eastus"
  vm_name           = "${var.infrastructure_prefix}-vm"
  vm_size           = "Standard_B1s"
  admin_username    = "azureuser"
  image_publisher   = "Canonical"
  image_offer       = "0001-com-ubuntu-server-jammy"
  image_sku         = "22_04-lts-gen2"
  image_version     = "latest"
  vnet_address_cidr = "10.0.0.0/16"
  subnet_prefix     = "10.0.1.0/24"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  address_space       = [local.vnet_address_cidr]
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = "${var.infrastructure_prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_prefix]
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.infrastructure_prefix}-nsg"
  location            = local.location
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

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                  = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.infrastructure_prefix}-pip"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "this" {
  name                = "${var.infrastructure_prefix}-nic"
  location            = local.location
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

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = local.vm_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  size                = local.vm_size

  admin_username                  = local.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm_key.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.this.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.image_publisher
    offer     = local.image_offer
    sku       = local.image_sku
    version   = local.image_version
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF
  )
}

output "vm_name" {
  description = "Name of the VM"
  value       = azurerm_linux_virtual_machine.this.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.this.ip_address
}

output "admin_username" {
  description = "Default admin username"
  value       = local.admin_username
}
