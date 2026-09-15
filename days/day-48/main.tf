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

provider "docker" {
  registry_auth {
    address  = azurerm_container_registry.this.login_server
    username = var.client_id
    password = var.client_secret
  }
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

variable "azure_region" {
  description = "Azure region for deployed resources"
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

variable "resource_suffix" {
  description = "Numeric suffix used for the ACR and storage account names, such as 323730418."
  type        = number

  validation {
    condition     = var.resource_suffix > 0 && var.resource_suffix == floor(var.resource_suffix)
    error_message = "resource_suffix must be a positive whole number."
  }
}

variable "dockerfile_path" {
  description = "Linux-host path to the Docker build context, such as /root/pyapp."
  type        = string
  default     = "/root/pyapp"
}

variable "config_file_path" {
  description = "Linux-host path to config.json."
  type        = string
  default     = "/root/config.json"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  vm_name              = "${var.infrastructure_prefix}-vm"
  acr_name             = "${var.infrastructure_prefix}acr${var.resource_suffix}"
  storage_account_name = "${var.infrastructure_prefix}stor${var.resource_suffix}"
  repository_name      = "${var.infrastructure_prefix}/python-app"
  image_name           = "${local.repository_name}:latest"
  image_uri            = "${local.acr_name}.azurecr.io/${local.image_name}"
  container_name       = "${var.infrastructure_prefix}-python-app"
  storage_container    = "${var.infrastructure_prefix}-config"
  admin_username       = "azureuser"
  ssh_key_path         = pathexpand("~/.ssh/id_rsa")
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
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      printf '%s\n' "$SSH_PRIVATE_KEY" > "$SSH_KEY_PATH"
      chmod 600 "$SSH_KEY_PATH"
    BASH
  }
}

resource "azurerm_container_registry" "this" {
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.azure_region
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "config" {
  name               = local.storage_container
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_storage_blob" "config" {
  name                 = "config.json"
  storage_container_id = azurerm_storage_container.config.id
  type                 = "Block"
  source               = var.config_file_path
  content_type         = "application/json"
}

resource "docker_image" "python_app" {
  name = local.image_uri

  build {
    context = var.dockerfile_path
  }
}

resource "docker_registry_image" "python_app" {
  name          = docker_image.python_app.name
  keep_remotely = true

  triggers = {
    image_id = docker_image.python_app.image_id
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.infrastructure_prefix}-vnet"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.48.0.0/16"]
}

resource "azurerm_subnet" "vm" {
  name                 = "${var.infrastructure_prefix}-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.48.0.0/24"]
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
  name                = "${var.infrastructure_prefix}-vm-ip"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.infrastructure_prefix}-vm-nic"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "this" {
  depends_on = [docker_registry_image.python_app]

  name                            = local.vm_name
  location                        = var.azure_region
  resource_group_name             = data.azurerm_resource_group.this.name
  size                            = "Standard_B1s"
  admin_username                  = local.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.this.primary_blob_endpoint
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
      - docker.io
      - curl
    runcmd:
      - systemctl enable --now docker
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  CLOUD_INIT
  )
}

resource "time_sleep" "wait_15_seconds" {
  depends_on = [azurerm_linux_virtual_machine.this]

  create_duration = "15s"
}

resource "terraform_data" "configure_vm" {

  depends_on = [
    terraform_data.write_ssh_key,
    time_sleep.wait_15_seconds
]

  triggers_replace = [
    azurerm_linux_virtual_machine.this.id,
    docker_registry_image.python_app.id
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      VM_PUBLIC_IP      = azurerm_public_ip.vm.ip_address
      ACR_NAME          = azurerm_container_registry.this.name
      IMAGE_URI         = local.image_uri
      CONTAINER_NAME    = local.container_name
      STORAGE_ACCOUNT   = azurerm_storage_account.this.name
      STORAGE_CONTAINER = azurerm_storage_container.config.name
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
      sudo chmod o+rw /var/run/docker.sock
      az login \
        --service-principal \
        --username "$CLIENT_ID" \
        --password "$CLIENT_SECRET" \
        --tenant "$TENANT_ID" \
        --subscription "$SUBSCRIPTION_ID"
      az storage blob download --account-name $STORAGE_ACCOUNT --container-name $STORAGE_CONTAINER --name config.json --file /home/azureuser/config.json --auth-mode login --overwrite
      az acr login --name $ACR_NAME
      docker pull $IMAGE_URI
      docker rm -f $CONTAINER_NAME 2>/dev/null || true
      docker run -d --name $CONTAINER_NAME --restart unless-stopped -p 80:80 -v /home/azureuser/config.json:/app/config.json:ro $IMAGE_URI
      REMOTE_COMMAND
      )
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY_PATH" "azureuser@$VM_PUBLIC_IP" "$remote_command"
    BASH
  }
}

output "vm_public_ip" {
  description = "Public IP address of the Python application VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "acr_login_server" {
  description = "ACR login server containing the application image."
  value       = azurerm_container_registry.this.login_server
}

output "image_uri" {
  description = "Fully qualified ACR image URI."
  value       = local.image_uri
}

output "storage_container_name" {
  description = "Blob container containing config.json."
  value       = azurerm_storage_container.config.name
}

output "ssh_private_key" {
  description = "Generated SSH private key for the VM."
  value       = tls_private_key.vm.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Generated SSH public key installed for azureuser."
  value       = tls_private_key.vm.public_key_openssh
}