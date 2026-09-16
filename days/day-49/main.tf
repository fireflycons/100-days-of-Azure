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

variable "resource_suffix" {
  description = "Numeric suffix used for the storage account name, such as 954575234."
  type        = number

  validation {
    condition     = var.resource_suffix > 0 && var.resource_suffix == floor(var.resource_suffix)
    error_message = "resource_suffix must be a positive whole number."
  }
}

variable "client_id" {
  description = "Client ID used to authenticate Docker pushes to ACR."
  type        = string
}

variable "client_secret" {
  description = "Client secret used to authenticate Docker pushes to ACR."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID used by the VM service-principal login."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID used by the VM service-principal login."
  type        = string
}

variable "index_file_path" {
  description = "Linux-host path to the index.html file."
  type        = string
  default     = "/root/index.html"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  vm_name           = "${var.infrastructure_prefix}-vm"
  vnet_name         = "${var.infrastructure_prefix}-vnet"
  subnet_name       = "${var.infrastructure_prefix}-subnet"
  storage_name      = "${var.infrastructure_prefix}stor${var.resource_suffix}"
  storage_container = "${var.infrastructure_prefix}-container"
  admin_username    = "azureuser"
  ssh_key_path      = pathexpand("~/.ssh/id_rsa")
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "terraform_data" "write_ssh_key" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      SSH_PRIVATE_KEY = tls_private_key.vm.private_key_pem
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

resource "azurerm_storage_account" "this" {
  name                            = local.storage_name
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = var.azure_region
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  public_network_access           = "Enabled"
}

resource "azurerm_storage_container" "this" {
  name                  = local.storage_container
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "index" {
  name                 = "index.html"
  storage_container_id = azurerm_storage_container.this.id
  type                 = "Block"
  source               = var.index_file_path
  content_type         = "text/html"
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.49.0.0/16"]
}

resource "azurerm_subnet" "this" {
  name                 = local.subnet_name
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.49.0.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = "${local.vm_name}-nsg"
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

resource "azurerm_public_ip" "this" {
  name                = "${local.vm_name}-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "this" {
  name                = "${local.vm_name}-nic"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
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
  name                            = local.vm_name
  location                        = var.azure_region
  resource_group_name             = data.azurerm_resource_group.this.name
  size                            = "Standard_B1s"
  admin_username                  = local.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  identity {
    type = "SystemAssigned"
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
      - curl
    runcmd:
      - systemctl enable --now nginx
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  CLOUD_INIT
  )
}

resource "terraform_data" "configure_vm" {
  depends_on = [
    terraform_data.write_ssh_key,
    azurerm_storage_blob.index
  ]

  triggers_replace = [
    azurerm_linux_virtual_machine.this.id,
    azurerm_storage_blob.index.id,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      VM_PUBLIC_IP      = azurerm_public_ip.this.ip_address
      STORAGE_ACCOUNT   = azurerm_storage_account.this.name
      STORAGE_CONTAINER = azurerm_storage_container.this.name
      SSH_KEY_PATH      = local.ssh_key_path
      CLIENT_ID         = var.client_id
      CLIENT_SECRET     = var.client_secret
      TENANT_ID         = var.tenant_id
      SUBSCRIPTION_ID   = var.subscription_id
    }

    command = <<-BASH
      set -euo pipefail
      remote_command=$(cat <<REMOTE_COMMAND
      set -e
      while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done
      az login \
        --service-principal \
        --username "$CLIENT_ID" \
        --password "$CLIENT_SECRET" \
        --tenant "$TENANT_ID" \
        --subscription "$SUBSCRIPTION_ID"
      az storage blob download \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$STORAGE_CONTAINER" \
        --name index.html \
        --file index.html \
        --auth-mode login \
        --overwrite
      sudo mv index.html /var/www/html/index.html
      sudo chown www-data:www-data /var/www/html/index.html
      sudo chmod 644 /var/www/html/index.html
      sudo systemctl restart nginx
      REMOTE_COMMAND
      )
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "azureuser@$VM_PUBLIC_IP" "$remote_command"
    BASH
  }
}

output "vm_public_ip" {
  description = "Public IP address of the Nginx VM."
  value       = azurerm_public_ip.this.ip_address
}

output "storage_account_name" {
  description = "Name of the private storage account containing index.html."
  value       = azurerm_storage_account.this.name
}

output "storage_container_name" {
  description = "Name of the private blob container containing index.html."
  value       = azurerm_storage_container.this.name
}
