# Task: Configuring Virtual Network Peering

The Nautilus DevOps team has been tasked with demonstrating the use of VNet Peering to enable communication between two VNets. One VNet will be a private VNet that contains a private Azure VM, while the other will be a public VNet containing a publicly accessible Azure VM.

## Task Details

1. Existing Azure Resources:
    * Public VM: `devops-pub-vm` is already in the public VNet.
    * Private VNet and VM: `devops-priv-vnet` and `devops-priv-vm` exist in the private VNet with its subnet: `devops-priv-subnet`.
1. Create VNet Peering:
    * Create a VNet Peering between the Public VNet and Private VNet.
    * VNet Peering Name: `devops-pub-to-priv-peering`.
1. Test the Connection:
    * SSH into the public VM and verify that you can ping the private VM.

Create the resources only in the `East US` region.