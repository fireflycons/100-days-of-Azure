# Task: Running Containers on Azure Virtual Machines

The Nautilus DevOps team needs to set up an Azure Virtual Machine (VM) to interact with an Azure Blob Storage container for storing and retrieving data. The team must create a private storage account, configure Blob Storage, and test the functionality.

## Task Details

1. Azure Virtual Machine Setup:
   - The VM named `datacenter-vm` already exists in the `East US` region.
1. Create a Private Storage Account and Blob Container:
   - Create a storage account named `datacenterstor21516` in the `East US` region with Locally-redundant storage (LRS).
   - Create a private Blob container named `datacenter-container21516`.
1. Retrieve Storage Account Key:
   - Get the storage account's access key to configure access for the application.
1. Create a Test File:
   - SSH into the VM and create a file named `testfile.txt` in the `/home/azureuser` directory with content: "this is a test file".
1. Upload the File to Blob Storage:
   - Upload the `testfile.txt` file to the Blob container `datacenter-container21516` using the Azure CLI command:
```
az storage blob upload \
    --account-name datacenterstor21516 \
    --account-key <access-key> \
    --container-name datacenter-container21516 \
    --name testfile.txt \
    --file /home/azureuser/testfile.txt
```

