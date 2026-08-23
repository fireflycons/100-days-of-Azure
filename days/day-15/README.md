# Task: Create and Configure Network Security Group (NSG) in Azure

The Nautilus DevOps team is strategizing the migration of a portion of their infrastructure to the Azure cloud. Recognizing the scale of this undertaking, they have opted to approach the migration in incremental steps rather than as a single massive transition. To achieve this, they have segmented large tasks into smaller, more manageable units. This granular approach enables the team to execute the migration in gradual phases, ensuring smoother implementation and minimizing disruption to ongoing operations. By breaking down the migration into smaller tasks, the Nautilus DevOps team can systematically progress through each stage, allowing for better control, risk mitigation, and optimization of resources throughout the migration process.

# Task Details

For this task, create a network security group (NSG) with the following requirements:

* Name of the NSG should be `xfusion-nsg`.
* Add an inbound security rule named `Allow-HTTP` for HTTP service on port `80`, with the source CIDR range of `0.0.0.0/0`.
* Add another inbound security rule named `Allow-SSH` for SSH service on port `22`, with the source CIDR range of `0.0.0.0/0`.