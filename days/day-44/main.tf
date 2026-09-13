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

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_network_interface" "vm" {
  name                = "${var.infrastructure_prefix}-vmVMNic"
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_public_ip" "vm" {
  name                = element(split("/", data.azurerm_network_interface.vm.ip_configuration[0].public_ip_address_id), length(split("/", data.azurerm_network_interface.vm.ip_configuration[0].public_ip_address_id)) - 1)
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_eventhub_namespace" "this" {
  name                = "${var.infrastructure_prefix}-namespace"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  sku                     = "Standard"
  auto_inflate_enabled     = true
  maximum_throughput_units = 10
}

resource "azurerm_eventhub" "this" {
  name              = "${var.infrastructure_prefix}-hub"
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = 2
  message_retention = 1
}

resource "azurerm_eventhub_authorization_rule" "send_logs" {
  name                = "${var.infrastructure_prefix}-send-logs"
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this.name
  resource_group_name = data.azurerm_resource_group.this.name
  listen              = false
  send                = true
  manage              = false
}

resource "terraform_data" "send_logs" {
  triggers_replace = [
    azurerm_eventhub.this.id,
    azurerm_eventhub_authorization_rule.send_logs.id,
    data.azurerm_public_ip.vm.ip_address,
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new azureuser@${data.azurerm_public_ip.vm.ip_address} <<'REMOTE_SCRIPT'
      event_hub_connection_string=$(printf '%s' '${base64encode(azurerm_eventhub_authorization_rule.send_logs.primary_connection_string)}' | base64 --decode)
      escaped_connection_string=$(printf '%s' "$event_hub_connection_string" | sed 's/[&\\/]/\\&/g')
      sed -i "s#<your_event_hub_connection_string>#$escaped_connection_string#" /home/azureuser/send_logs.py

      for i in 1 2 3 4 5; do
        python3 /home/azureuser/send_logs.py
      done
      REMOTE_SCRIPT
    EOT
  }
}

output "eventhub_namespace_name" {
  description = "Name of the Event Hubs namespace."
  value       = azurerm_eventhub_namespace.this.name
}

output "eventhub_name" {
  description = "Name of the Event Hub."
  value       = azurerm_eventhub.this.name
}

output "vm_public_ip" {
  description = "Public IP address used for the log sender SSH connection."
  value       = data.azurerm_public_ip.vm.ip_address
}
