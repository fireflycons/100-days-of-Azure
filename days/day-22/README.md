# Task: Configuring Instances with User Data

The Nautilus DevOps Team is working on setting up a new virtual machine (VM) to host a web server for a critical application. The team lead has requested you to create an Azure VM that will serve as a web server using Nginx. This VM will be part of the initial infrastructure setup for the Nautilus project. Ensuring that the server is correctly configured and accessible from the internet is crucial for the upcoming deployment phase.

# Task Details

As a member of the Nautilus DevOps Team, your task is to create a VM with the following specifications:

* Instance Name: The VM must be named `datacenter-vm`.
* Image: Use any available Ubuntu image to create this VM.
* Custom Script Extension/User Data: Configure the VM to run a custom script during its launch. This script should:
    * Install the Nginx package.
    * Start the Nginx service.
* Network Security Group (NSG): Ensure that the VM allows HTTP traffic on port 80 from the internet.
* Create the resources only in the `East US` region.
