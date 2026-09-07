terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.1"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

provider "azapi" {}

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
  description = "Azure region for the MySQL VM"
  type        = string

  validation {
    condition     = contains(["eastus", "westus", "centralus"], var.azure_region)
    error_message = "azure_region must be one of eastus, westus, centralus."
  }
}

locals {
  vm_name                = "${var.infrastructure_prefix}-mysql-vm"
  php_vm_name            = "${var.infrastructure_prefix}-php-vm"
  php_vm_admin_username  = "azureuser"
  admin_username         = "${var.infrastructure_prefix}_admin"
  mysql_database         = "${var.infrastructure_prefix}_db"
  mysql_user             = "${var.infrastructure_prefix}_user"
  vm_size                = "Standard_B1s"
  image_publisher        = "jetware-srl"
  image_offer            = "percona_mysql"
  image_sku              = "percona_mysql57-ubuntu-1604"
  image_version          = "1.0.170503"
  virtual_network        = "${var.infrastructure_prefix}-mysql-vnet"
  subnet                 = "${var.infrastructure_prefix}-mysql-subnet"
  network_interface      = "${var.infrastructure_prefix}-mysql-nic"
  network_security_group = "${var.infrastructure_prefix}-mysql-nsg"
  public_ip              = "${var.infrastructure_prefix}-mysql-public-ip"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_machine" "php" {
  name                = local.php_vm_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azapi_resource" "php" {
  type                   = "Microsoft.Compute/virtualMachines@2023-09-01"
  resource_id            = data.azurerm_virtual_machine.php.id
  response_export_values = ["properties.networkProfile.networkInterfaces"]
}

data "azurerm_network_interface" "php" {
  name = element(
    split(
      "/",
      data.azapi_resource.php.output.properties.networkProfile.networkInterfaces[0].id
    ),
    8
  )
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_public_ip" "php" {
  name = element(
    split("/", data.azurerm_network_interface.php.ip_configuration[0].public_ip_address_id),
    8
  )
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_virtual_network" "this" {
  name                = local.virtual_network
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = ["10.37.0.0/16"]
}

resource "azurerm_subnet" "this" {
  name                 = local.subnet
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.37.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = local.network_security_group
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  security_rule {
    name                       = "${var.infrastructure_prefix}-allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "${var.infrastructure_prefix}-allow-mysql"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "this" {
  name                = local.public_ip
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "this" {
  name                = local.network_interface
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.this.name

  ip_configuration {
    name                          = "primary"
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
  size                            = local.vm_size
  admin_username                  = local.admin_username
  admin_password                  = "Namin@123456"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.this.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.image_publisher
    offer     = local.image_offer
    sku       = local.image_sku
    version   = local.image_version
  }

  plan {
    name      = local.image_sku
    product   = local.image_offer
    publisher = local.image_publisher
  }

  custom_data = base64encode(<<-CUSTOM_DATA
    #cloud-config
    runcmd:
      - |
        /jet/bin/mysql <<'SQL'
        CREATE DATABASE ${local.mysql_database};
        CREATE USER '${local.mysql_user}'@'%' IDENTIFIED BY 'password123';
        GRANT ALL PRIVILEGES ON ${local.mysql_database}.* TO '${local.mysql_user}'@'%';
        GRANT ALL PRIVILEGES ON ${local.mysql_database}.* TO '${local.mysql_user}'@'%';
        FLUSH PRIVILEGES;
        SQL
    CUSTOM_DATA
  )
}

resource "terraform_data" "configure_php_vm" {
  triggers_replace = [
    azurerm_linux_virtual_machine.this.id,
    data.azurerm_public_ip.php.ip_address,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-SHELL
      ssh -i ~/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${local.php_vm_admin_username}@${data.azurerm_public_ip.php.ip_address}" "sudo -n bash -s" <<'REMOTE_SCRIPT'
      target=/var/www/html/db_test.php
      temporary_file=$(mktemp)
      trap 'rm -f "$temporary_file"' EXIT
      cat > "$temporary_file" <<'PHP'
      <?php
          $servername = "${azurerm_public_ip.this.ip_address}";
          $username = "${local.mysql_user}";
          $password = "password123";
          $dbname = "${local.mysql_database}";
          $port = 3306;

          // Create connection
          $conn = new mysqli($servername, $username, $password, $dbname, $port);

          // Check connection
          if ($conn->connect_error) {
              die("Connection failed: " . $conn->connect_error);
          }
          echo "Connected successfully";
      ?>
      PHP
      mv "$temporary_file" "$target"
      chmod 644 "$target"
      trap - EXIT
      REMOTE_SCRIPT
    SHELL
  }
}

output "mysql_vm_public_ip" {
  description = "Public IP address of the MySQL VM"
  value       = azurerm_public_ip.this.ip_address
}