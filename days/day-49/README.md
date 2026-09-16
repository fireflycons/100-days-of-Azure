# Task: VM Setup with Web Storage Integration

The Nautilus DevOps team is tasked with setting up an environment to host a static web application. The application will serve static content from an Azure Storage Account, and a Virtual Machine (VM) will be configured to fetch and display this content using Nginx. The Azure Storage Account is used as a secure, centralized location for storing the index.html file. The team intentionally keeps this file outside the main source code repository, since that repository contains additional internal application code that should not be exposed to or accessed by the VM. By placing only the required static file in the Storage Account, the team can distribute this asset safely and independently of the full codebase.

The VM should securely download the index.html blob directly from the designated container (e.g., using Azure CLI, SAS URL, or REST API) and place it in Nginx’s web root directory so that it is served locally by Nginx. The Storage Account is not mounted, and the Static Website feature is not used. The VM retrieves the file during deployment and may re-fetch it whenever updates are needed. The resources must follow best practices for security, performance, and accessibility.

## Task Details

1. Create a Virtual Network (VNet) and Subnet:
    * Create a VNet named `datacenter-vnet` in the East US region.
    * Create a subnet named `datacenter-subnet` within the VNet for the VM.
2. Create an Azure Storage Account:
    * Create a storage account named `datacenterstor954575234` in the East US region with Locally-redundant storage (LRS).
    * Ensure the storage account prevents anonymous access by leaving Allow `enabling anonymous access on individual containers` unchecked under the Security tab. Keep `Public network access` set to Enable under the Networking tab so that authenticated deployment and grading scripts can still check the resource securely using the account key. All other options should be left as the default selections.
    * Create a Blob container named `datacenter-container` in the storage account.
    * Upload the `index.html` file located at /root on the client host to the container `datacenter-container`.
1. Create a Virtual Machine (VM):
    * Create a VM named `datacenter-vm` in the East US region.
    * Use the `datacenter-vnet` and subnet `datacenter-subnet` for the VM.
    * Authentication: Use SSH public key authentication. (Please select use existing public key option, create public-key locally and paste contents of `~/.ssh/id_rsa.pub`)
    * Install Nginx on the VM.
    * Download the `index.html` file using a command such as:
        ```
        sudo az storage blob download --account-name datacenterstor954575234 --account-key xxxxx --container-name datacenter-container --name index.html --file /var/www/html/index.html
        ```
    * Ensure Nginx is configured to serve the file from `/var/www/html/index.html`.
1. Verify Setup:
    * Verify that the Nginx web server on the client host serves the `index.html` file correctly when accessing the VM's public IP address.