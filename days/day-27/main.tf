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
  description = "Prefix used for resource names."
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

variable "resource_group_name" {
  description = "Existing resource group for the deployment."
  type        = string
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location           = "Central US"
  admin_username     = "azureadmin"
  vm_size            = "Standard_B1s"
  vnet_address_space = ["10.0.0.0/16"]
  subnet_address     = "10.0.0.0/24"
  ssh_source_address = "10.0.0.0/16"
  ssh_destination    = "10.0.0.0/16"
}

resource "azurerm_virtual_network" "private" {
  name                = "${var.infrastructure_prefix}-priv-vnet"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = local.vnet_address_space
}

resource "azurerm_subnet" "private" {
  name                 = "${var.infrastructure_prefix}-priv-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.private.name
  address_prefixes     = [local.subnet_address]
}

resource "azurerm_network_security_group" "private" {
  name                = "${var.infrastructure_prefix}-priv-nsg"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-VNet-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.ssh_source_address
    destination_address_prefix = local.ssh_destination
  }
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

resource "azurerm_network_interface" "private" {
  name                = "${var.infrastructure_prefix}-priv-nic"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "private" {
  name                            = "${var.infrastructure_prefix}-priv-vm"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = local.location
  size                            = local.vm_size
  admin_username                  = local.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.private.id]

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
