# Task: Managing Storage Lifecycle in Azure

The Nautilus DevOps team needs to optimize data retention costs by automating the deletion of old blobs. They plan to implement Blob Lifecycle Management for a specific container in Azure Storage.

# Task Details

1. Create a Storage Account:
    * Name the storage account `devopsstor4651`.
    * Set the region to `East US`.
    * Use Locally-redundant storage (LRS) as the redundancy option.
1. Create a Blob Container:
    * Name the container `devops-container4651`.
1. Upload a File to the Container:
    * Upload the file named `tempfile.txt` to the container. The file is present under `/root` of the client host.
1. Configure Blob Lifecycle Management:
    * Apply a Lifecycle Management rule named `devops-del-rule` to the container `devops-container4651` to delete blobs after 7 days of last modification.
1. Validation:
    * Verify that the Lifecycle Management rule named `devops-del-rule` is correctly applied.

Create the resources only in the `East US` region.