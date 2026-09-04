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
  location          = "centralus"
  web_app_name      = "${var.infrastructure_prefix}-webapp"
  service_plan_name = "${var.infrastructure_prefix}-learn-python"
  tags = {
    Name        = "WebAppLearning"
    Environment = "Dev"
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_service_plan" "python" {
  name                = local.service_plan_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

resource "azurerm_linux_web_app" "python" {
  name                = local.web_app_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  service_plan_id     = azurerm_service_plan.python.id
  enabled             = true
  https_only          = true
  tags                = local.tags

  site_config {
    application_stack {
      python_version = "3.14"
    }
  }
}