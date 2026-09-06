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
  load_balancer_name      = "${var.infrastructure_prefix}-lb"
  frontend_ip_name        = "${var.infrastructure_prefix}-lb-ip"
  backend_pool_name       = "${var.infrastructure_prefix}-backend-pool"
  health_probe_name       = "${var.infrastructure_prefix}-health-probe"
  load_balancer_rule_name = "${var.infrastructure_prefix}-lb-rule"
  network_interface_name  = "${var.infrastructure_prefix}-vmVMNic"
  network_security_group  = "${var.infrastructure_prefix}-vmNSG"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_network_interface" "vm" {
  name                = local.network_interface_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_network_security_group" "vm" {
  name                = local.network_security_group
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_public_ip" "load_balancer" {
  name                = local.frontend_ip_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "this" {
  name                = local.load_balancer_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.load_balancer.id
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = local.backend_pool_name
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  network_interface_id    = data.azurerm_network_interface.vm.id
  ip_configuration_name   = data.azurerm_network_interface.vm.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

resource "azurerm_lb_probe" "this" {
  name            = local.health_probe_name
  loadbalancer_id = azurerm_lb.this.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "this" {
  name                           = local.load_balancer_rule_name
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = local.frontend_ip_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this.id
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "${var.infrastructure_prefix}-allow-http"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix = "*"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = data.azurerm_network_security_group.vm.name
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.load_balancer.ip_address
}