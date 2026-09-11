# Task: Working with Azure Table Storage
The Nautilus DevOps team is developing a simple 'To-Do' application using Azure Table Storage to store and manage tasks efficiently. The team needs to create an Azure Table to hold tasks, each identified by a unique `taskId`. Each task will have a description and a status, which indicates the progress of the task (e.g., 'completed' or 'in-progress').

## Task Details

1. Create an Azure Storage Account named `xfusiontablest7199` with a Table Storage table called `tasks`.
1. Insert the following tasks into the table:
   - Task 1: PartitionKey: `tasks`, RowKey: `1`, description: `Learn Table Storage`, status: `completed`
   - Task 2: PartitionKey: `tasks`, RowKey: `2`, description: `Build To-Do App`, status: `in-progress`
1. Verify that **Task 1** has a status of `completed` and **Task 2** has a status of `in-progress`.

