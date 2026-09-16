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
  admin_username = "azureuser"
  ssh_key_path   = pathexpand("~/.ssh/id_rsa")
}

resource "tls_private_key" "vms" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "terraform_data" "write_ssh_key" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      SSH_PRIVATE_KEY = tls_private_key.vms.private_key_pem
      SSH_KEY_PATH    = local.ssh_key_path
    }

    command = <<-BASH
      set -euo pipefail
      mkdir -p "$(dirname "$SSH_KEY_PATH")"
      chmod 700 "$(dirname "$SSH_KEY_PATH")"
      printf '%s\n' "$SSH_PRIVATE_KEY" > "$SSH_KEY_PATH"
      chmod 600 "$SSH_KEY_PATH"
    BASH
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "vm" {
  name                 = "${var.infrastructure_prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.50.0.0/24"]
}

resource "azurerm_subnet" "application_gateway" {
  name                 = "${var.infrastructure_prefix}-apgw-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_network_security_group" "vm" {
  name                = "${var.infrastructure_prefix}-vm-nsg"
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

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vm" {
  count               = 2
  name                = "${var.infrastructure_prefix}-vm${count.index + 1}-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm" {
  count               = 2
  name                = "${var.infrastructure_prefix}-vm${count.index + 1}-nic"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.vm[count.index].id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count                           = 2
  name                            = "${var.infrastructure_prefix}-vm${count.index + 1}"
  location                        = var.azure_region
  resource_group_name             = data.azurerm_resource_group.this.name
  size                            = "Standard_B1s"
  admin_username                  = local.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm[count.index].id]

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vms.public_key_openssh
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
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /var/www/html/index.html
        owner: www-data:www-data
        permissions: '0644'
        content: |
          Welcome to KKE Labs:Version ${count.index + 1}
    runcmd:
      - systemctl enable --now nginx
  CLOUD_INIT
  )
}

resource "azurerm_public_ip" "application_gateway" {
  name                = "${var.infrastructure_prefix}-apgw-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.infrastructure_prefix}-apgw"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.infrastructure_prefix}-apgw-ip-config"
    subnet_id = azurerm_subnet.application_gateway.id
  }

  frontend_port {
    name = "${var.infrastructure_prefix}-apgw-port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.infrastructure_prefix}-apgw-ip"
    public_ip_address_id = azurerm_public_ip.application_gateway.id
  }

  backend_address_pool {
    name         = "${var.infrastructure_prefix}-backend-pool"
    ip_addresses = [for network_interface in azurerm_network_interface.vm : network_interface.private_ip_address]
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
    frontend_ip_configuration_name = "${var.infrastructure_prefix}-apgw-ip"
    frontend_port_name             = "${var.infrastructure_prefix}-apgw-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.infrastructure_prefix}-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.infrastructure_prefix}-listener"
    backend_address_pool_name  = "${var.infrastructure_prefix}-backend-pool"
    backend_http_settings_name = "${var.infrastructure_prefix}-http-settings"
    priority                   = 100
  }
}

output "application_gateway_public_ip" {
  description = "Public IP address for the Application Gateway."
  value       = azurerm_public_ip.application_gateway.ip_address
}

output "vm_public_ips" {
  description = "Public IP addresses for the backend VMs."
  value       = azurerm_public_ip.vm[*].ip_address
}

output "ssh_private_key_path" {
  description = "Path where the shared SSH private key is written on the Linux apply host."
  value       = local.ssh_key_path
}