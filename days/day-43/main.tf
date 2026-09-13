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

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  vm_size            = "Standard_B1s"
  vm_image_publisher = "Canonical"
  vm_image_offer     = "ubuntu-24_04-lts"
  vm_image_sku       = "server-gen1"
  vm_image_version   = "latest"
  admin_username     = "azureuser"
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.43.0.0/16"]
}

resource "azurerm_subnet" "application_gateway" {
  name                 = "${var.infrastructure_prefix}-agw-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.43.0.0/24"]
}

resource "azurerm_subnet" "vm" {
  name                 = "${var.infrastructure_prefix}-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.43.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.infrastructure_prefix}-nsg"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.infrastructure_prefix}-vm-nic"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.infrastructure_prefix}-vm"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  size                = local.vm_size

  admin_username                  = local.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  network_interface_ids = [azurerm_network_interface.vm.id]

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

  custom_data = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - systemctl enable --now nginx
  CLOUD_INIT
  )
}

resource "azurerm_public_ip" "application_gateway" {
  name                = "${var.infrastructure_prefix}-agw-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.infrastructure_prefix}-agw"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.infrastructure_prefix}-agw-ip-config"
    subnet_id = azurerm_subnet.application_gateway.id
  }

  frontend_port {
    name = "${var.infrastructure_prefix}-frontend-port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.infrastructure_prefix}-frontend-ip"
    public_ip_address_id = azurerm_public_ip.application_gateway.id
  }

  backend_address_pool {
    name         = "${var.infrastructure_prefix}-backendpool"
    ip_addresses = [azurerm_network_interface.vm.private_ip_address]
  }

  backend_http_settings {
    name                  = "${var.infrastructure_prefix}-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "${var.infrastructure_prefix}-listener"
    frontend_ip_configuration_name = "${var.infrastructure_prefix}-frontend-ip"
    frontend_port_name             = "${var.infrastructure_prefix}-frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.infrastructure_prefix}-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.infrastructure_prefix}-listener"
    backend_address_pool_name  = "${var.infrastructure_prefix}-backendpool"
    backend_http_settings_name = "${var.infrastructure_prefix}-http-settings"
    priority                   = 100
  }
}

output "application_gateway_public_ip" {
  description = "Public IP address for the Application Gateway."
  value       = azurerm_public_ip.application_gateway.ip_address
}

output "vm_private_ip" {
  description = "Private IP address used by the Application Gateway backend pool."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "ssh_private_key" {
  description = "Generated RSA private key for the VM."
  value       = tls_private_key.vm.private_key_pem
  sensitive   = true
}