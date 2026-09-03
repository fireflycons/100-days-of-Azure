terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

provider "docker" {
  registry_auth {
    address  = "${local.repository_name}.azurecr.io"
    username = var.client_id
    password = var.client_secret
  }

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
  description = "Name of the existing resource group"
  type        = string
}

variable "client_id" {
  description = "Client ID for the service principal"
  type        = string
}

variable "client_secret" {
  description = "Client secret for the service principal"
  type        = string
}

variable "repository_name_suffix" {
  description = "Suffix appended to the infrastructure prefix for the ACR name (e.g. acr3932)"
  type        = string
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location        = "East US"
  repository_name = "${var.infrastructure_prefix}${var.repository_name_suffix}"
  creds           = jsondecode(file("/opt/creds.json"))
}

resource "azurerm_container_registry" "this" {
  name                = local.repository_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  sku                 = "Basic"
}

resource "docker_image" "this" {
  name = "${azurerm_container_registry.this.login_server}/${local.repository_name}:latest"

  build {
    context = "/root/pyapp"
  }
}

resource "docker_registry_image" "this" {
  name = docker_image.this.name
}

output "repository_domain_name" {
  description = "Domain name of the Azure Container Registry"
  value       = azurerm_container_registry.this.login_server
}

output "image_tag" {
  description = "Tag of the Docker image"
  value       = docker_image.this.name
}