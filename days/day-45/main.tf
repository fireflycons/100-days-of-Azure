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

variable "azure_region" {
  description = "Azure region for deployed resources"
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

locals {
  cluster_name = "${var.infrastructure_prefix}-aks"
  cluster_dns  = "${var.infrastructure_prefix}-aks"
  kubernetes_version = "1.36.3"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# Generate a random suffix for cluster's DNS prefix
resource "random_string" "dns" {
  length  = 6
  upper   = false
  lower   = false
  numeric = true
  special = false
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = local.kubernetes_version

  sku_tier                     = "Free"
  private_cluster_enabled      = true
  role_based_access_control_enabled = true
  local_account_disabled      = false

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name                = "agentpool"
    vm_size             = "Standard_D2s_v3"
    node_count          = 1
    auto_scaling_enabled = true
    min_count           = 1
    max_count           = 2
    os_disk_size_gb     = 30
    os_sku              = "Ubuntu"
    type                = "VirtualMachineScaleSets"
    zones               = ["1", "2", "3"]
  }

  tags = {
    environment = "dev"
    workload    = "aks"
  }
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_version" {
  description = "AKS Kubernetes version"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "private_cluster_enabled" {
  description = "Whether the AKS API server is private-only"
  value       = azurerm_kubernetes_cluster.aks.private_cluster_enabled
}

output "node_pool_vm_size" {
  description = "VM size used by the default node pool"
  value       = azurerm_kubernetes_cluster.aks.default_node_pool[0].vm_size
}
