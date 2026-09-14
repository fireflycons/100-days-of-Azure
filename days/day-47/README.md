# Task: SQL Database Migration and Setup
The Nautilus DevOps team is strategizing the migration of a portion of their infrastructure to Azure. Recognizing the scale of this undertaking, they have opted to approach the migration in incremental steps rather than as a single massive transition. As part of this migration, they are focusing on setting up and managing Azure SQL Databases, implementing backup processes, and ensuring data recovery. Below are the tasks they require you to perform:

## Task Details

**Task 1: Create an Azure SQL Database**
1. Create a publicly accessible Azure SQL Database instance with the following details:
    - Database Name: `devops-sqldb`.
    - Server Name: `devops-server-263123964`.
    - Backup Storage Redundancy: `Locally-redundant backup storage`.
    - Hardware Configuration: `Basic (For less demanding workloads)`.
    - Admin Username: `devops-admin`.
    - Admin Password: Set an appropriate password.
    - Database Size: Set to `2 GiB`.
    - Keep all other configurations as default.
2. Ensure the database is in the `Ready` state.

**Task 2: Create a Storage Account**
1. Create a Storage Account named `devopsst263123964`.
2. Configure a Blob Container named `devops-container-7913` within this storage account.

**Task 3: Backup the Azure SQL Database**
1. Take a backup of the Azure SQL Database instance `devops-sqldb` and store it in the Blob Container:
    - Storage Account: `devopsst263123964`.
    - Blob Container: `devops-container-263123964`.
    - Backup File Name: `devops-db-backup`.
2. Ensure the backup is fully exported to the blob container.

**Task 4: Download the Backup**
1. Download the backup file from the Blob Container to the `/opt` directory on the `azure-client` host.
2. Ensure the file is accessible and properly named based on its extension.

**Requirements for Completion**
- Ensure the SQL Database is in the `Ready` state.
- Confirm the backup is stored in the specified Blob Container.
- Verify the backup file is successfully downloaded to the `/opt` directory on the client host.

