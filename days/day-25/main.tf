terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
  }
}

provider "azapi" {}

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
  description = "Name of the existing resource group"
  type        = string
}

locals {
  vm_name         = "${var.infrastructure_prefix}-vm"
  data_disk_name  = "${var.infrastructure_prefix}-disk"
  data_disk_size  = 64
  mount_point     = "/mnt/${var.infrastructure_prefix}-disk"
  disk_device     = "/dev/disk/azure/scsi1/lun0"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "this" {
  name                = local.vm_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azapi_resource" "vm" {
  type                   = "Microsoft.Compute/virtualMachines@2024-03-01"
  resource_id            = data.azurerm_virtual_machine.this.id
  response_export_values = ["properties.storageProfile.osDisk.managedDisk.id"]
}

resource "azapi_update_resource" "os_disk" {
  type        = "Microsoft.Compute/disks@2026-03-02"
  resource_id = data.azapi_resource.vm.output.properties.storageProfile.osDisk.managedDisk.id

  body = {
    properties = {
      diskSizeGB = 64
    }
  }

  depends_on = [azapi_resource_action.deallocate]
}

resource "azapi_resource_action" "deallocate" {
  type        = "Microsoft.Compute/virtualMachines@2024-03-01"
  resource_id = data.azurerm_virtual_machine.this.id
  action      = "deallocate"
  method      = "POST"
}

resource "azurerm_managed_disk" "data" {
  name                 = local.data_disk_name
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = local.data_disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = data.azurerm_virtual_machine.this.id
  lun                = 0
  caching            = "ReadWrite"

  depends_on = [azapi_update_resource.os_disk]
}

resource "azapi_resource_action" "start" {
  type        = "Microsoft.Compute/virtualMachines@2024-03-01"
  resource_id = data.azurerm_virtual_machine.this.id
  action      = "start"
  method      = "POST"

  depends_on = [azurerm_virtual_machine_data_disk_attachment.data]
}

resource "azurerm_virtual_machine_extension" "mount_data_disk" {
  name                       = "${var.infrastructure_prefix}-mount-data-disk"
  virtual_machine_id         = data.azurerm_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = <<-EOT
      set -eu
      device="${local.disk_device}"
      mount_point="${local.mount_point}"
      mkdir -p "$mount_point"
      if ! blkid "$device" >/dev/null 2>&1; then mkfs.ext4 "$device"; fi
      mountpoint -q "$mount_point" || mount "$device" "$mount_point"
    EOT
  })

  depends_on = [
    azapi_resource_action.start,
  ]
}

output "vm_id" {
  description = "The ID of the updated virtual machine"
  value       = data.azurerm_virtual_machine.this.id
}

output "data_disk_id" {
  description = "The ID of the attached data disk"
  value       = azurerm_managed_disk.data.id
}

output "mount_point" {
  description = "Mount point configured on the virtual machine"
  value       = local.mount_point
}