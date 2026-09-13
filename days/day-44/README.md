# Task: Integrating Azure Event Hub with Virtual Machines
The Nautilus DevOps team wants to integrate an Azure Virtual Machine with Azure Event Hubs for centralized log collection. Follow these steps to complete the task.

## Task Details

1. **Create Azure Event Hubs Namespace:**
   - Create an Event Hubs namespace named `datacenter-namespace` in the East US region
   - Select the Standard pricing tier. Make sure to enable `Enable Auto-inflate`

1. **Create an Event Hub:**
   - Within the namespace, create an Event Hub named `datacenter-hub`

1. **Verify the Virtual Machine Configuration:**
   - A VM named `datacenter-vm` already exists
   - A Python script named `send_logs.py` already exists on the VM under `/home/azureuser`. This script is used to send logs to the Event Hub. Make sure to execute this script multiple times

1. **Verify Logs:**
   - Ensure the logs are successfully sent to the Event Hub by checking the Event Hubs metrics in the Azure portal
