# Task: Convert Public Azure Blob Container to Private

The Nautilus DevOps team has been using Azure Blob Storage to manage their data. Recently, they realized that one of their containers, currently public, needs to be restricted for internal use only. Your task is to convert a public Azure Blob container to private.

Two blob containers named `devops-container-31464` and `devops-priv-31823` are available in the `westus` region within the storage account `devopsst32007`. The `devops-container-31464` is currently public, and `devops-priv-31823` is private.

# Task Details
1. Convert the blob container `devops-container-31464` from public to private while leaving `devops-priv-31823` unchanged.
1. Make sure the access level for `devops-container-31464` is set to private with no public access.