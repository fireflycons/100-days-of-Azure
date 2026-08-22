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
  vm_location        = "southcentralus"
  vm_size            = "Standard_B1s"
  vm_image_publisher = "Canonical"
  vm_image_offer     = "ubuntu-24_04-lts"
  vm_image_sku       = "server-gen1"
  vm_image_version   = "latest"
  data_disk_size_gb  = 30
  data_disk_type     = "Standard_LRS"
  admin_username     = "azureuser"
}

resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
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
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.infrastructure_prefix}-public-ip"
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
    name                          = "testconfiguration1"
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

  admin_username = local.admin_username

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

resource "azurerm_managed_disk" "data_disk" {
  name                 = "${var.infrastructure_prefix}-datadisk"
  location             = local.vm_location
  resource_group_name  = data.azurerm_resource_group.this.name
  storage_account_type = local.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = local.data_disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = 0
  caching            = "ReadWrite"
}

output "vm_id" {
  description = "The ID of the created virtual machine"
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_private_ip" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.this.private_ip_address
}

output "vm_public_ip" {
  description = "The public IP address for internet access to the virtual machine"
  value       = azurerm_public_ip.this.ip_address
}
