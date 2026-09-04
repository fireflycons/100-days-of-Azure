# Task: Create Azure SQL Database

The Nautilus Devops team is strategizing the migration of a portion of their infrastructure to Azure. Recognizing the scale of this undertaking, they have opted to approach the migration in incremental steps rather than as a single massive transition. Recently, they started working on creating and configuring some database instances on Azure.

## Task Details

For this task, create one publicly accessible Azure SQL Database instance along with the following details:

1. The name of the Azure SQL Database must be `nautilus-sqldb`.
1. The server name must be `nautilus-server-2353` under `westus`.
1. The compute + storage configuration should be **Basic (For less demanding workloads)**.
1. The backup storage redundancy should be **Locally-redundant backup storage**.
1. Set the login admin username to `nautilus-admin` and set an appropriate password.
1. Set the database size to **2 GiB**.
1. Keep the rest of the configurations as default. Finally, make sure the database is in the Ready state before submitting this task.


