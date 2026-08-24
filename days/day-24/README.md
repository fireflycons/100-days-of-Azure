# Task: Securing Virtual Machine SSH Access

The Nautilus DevOps team needs to set up a new Virtual Machine (VM) on the Azure cloud that can be accessed securely from their landing host (`azure-client`). Follow the steps below to complete this task:

# Task Details

* Create an SSH Key: On the `azure-client` host, check if an SSH key already exists. If it doesn’t exist, create a new SSH key on the `azure-client` host that will be used for password-less SSH access.
* Create a Virtual Machine: Use the Azure Portal or Azure CLI to create a new Virtual Machine named `devops-vm` in the `westus` region. Set the VM size to Standard_B1s and configure the VM with SSH access for the `azureuser` account using the newly created SSH key.
* Configure SSH Access: Ensure that the SSH key from the `azure-client` host is added to the `azureuser` account on `devops-vm`, enabling secure, password-less SSH access from the `azure-client` host.
* Verify Connectivity: Test the connection from `azure-client` to `devops-vm` using SSH to confirm that password-less access has been set up correctly.

