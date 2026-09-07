# Task: Setting Up MySQL on a Virtual Machine in Azure

The Nautilus DevOps team is tasked with integrating a PHP application hosted on an Azure VM with a MySQL database hosted on another Azure VM. This will validate the application's ability to connect to the database in the cloud.

## Task Details
1. Create the MySQL VM:
   - Create a VM named `datacenter-mysql-vm` using the Percona Server for MySQL image (published by Jetware) from the Azure Marketplace.
   - Configure the VM in the East US region.
   - Use `Password` as the authentication type.
   - Set the username as `datacenter_admin` and the password as `Namin@123456`.
   - Allow inbound traffic on port `3306` to enable MySQL access.

1. Setup the MySQL Database:
   - SSH into the `datacenter-mysql-vm`.
   - Use the `sudo /jet/enter mysql` command to access the MySQL shell.
   - Create a database named `datacenter_db`.
   - Create a MySQL user named `datacenter_user` with password `password123`.
   - Grant all privileges on the `datacenter_db` database to this user.

1. PHP VM Setup:
   - A VM named `datacenter-php-vm` already exists in the East US region.
   - This VM is hosting a PHP application and contains a pre-existing `db_test.php` file in the `/var/www/html/` directory.

1. Database Connection Configuration:
   - Retrieve the public IP address of the `datacenter-mysql-vm`.
   - Update the database connection settings in the `db_test.php` file to use the MySQL credentials and public IP address of the `datacenter-mysql-vm`.

1. Validation:
   - Access the `db_test.php` file from the `datacenter-php-vm` using its public IP address.
   - Ensure the file displays the message `Connected successfully`, confirming the connection between the PHP application and the MySQL database.
