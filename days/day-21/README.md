# Task: Assigning Public IP to Virtual Machines

The Nautilus DevOps Team has received a new request from the Development Team to set up a new Azure Virtual Machine (VM). This VM will be used to host a new application that requires a stable public IP address. To ensure that the VM has a consistent public IP, a Static Public IP address needs to be associated with it. The VM will be named `nautilus-vm`, and the Static Public IP will be named `nautilus-pip`. This setup will help the Development Team to have a reliable and consistent access point for their application.

# Task Details

1. Create an Azure VM named `nautilus-vm` using any available Ubuntu image, with the VM size `Standard_B1s`.
1. Generate an SSH public key on the azure-client host and associate it with the VM for SSH access.
1. Associate a Static Public IP address named `nautilus-pip` with this VM.
1. Ensure the VM is accessible via SSH using the generated public key.

Perform all operations in the `Central US` region.
