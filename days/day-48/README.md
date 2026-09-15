# Task: VM and ACR Integration for Storage
The Nautilus DevOps team needs to set up an Azure Virtual Machine (VM) to interact with an Azure Blob Storage container for storing and retrieving data. The team must create a private storage account, configure Blob Storage, and test the functionality.

Task:

1. Azure Virtual Machine Setup:
    - Create a VM named `nautilus-vm` in the `East US` region.
    - Authentication: Use `SSH public key` authentication. (Please select `use existing public key` option, create public-key locally and paste contents of `~/.ssh/id_rsa.pub`).
    - Install Docker and Azure CLI on the VM.
    - Pull the Docker image from the ACR and run it on the VM, ensuring it listens on port `80`.

2. Azure Container Registry (ACR) Setup:
    - Create an ACR named `nautilusacr323730418` in the East US region.
    - The repository name should be `nautilus/python-app`.
    - Build the Docker image using the Dockerfile already given under `/root/pyapp`.
    - Push the Docker image to the ACR with the tag `latest`.

3. Create a Storage Account and Blob Container:
    - Create a storage account named `nautilusstor323730418` in the East US region with `Locally-redundant storage (LRS)`.
    - Create a Blob container named `nautilus-config`.
    - Upload a file named `config.json` (available under `/root/`) to the container.

4. Validation:
    - Confirm that the application can be accessed on the browser.

