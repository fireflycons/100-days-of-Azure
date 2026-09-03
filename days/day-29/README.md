# Task: Working with Azure Container Registry (ACR)

The Nautilus DevOps team has been tasked with setting up a containerized application. They need to create an Azure Container Registry (ACR) to store their Docker images. Once the repository is created, they will build a Docker image from a Dockerfile located on the azure-client host and push this image to the ACR repository.

## Task Details

* Create an ACR repository named `xfusionacr3932` under East US. Pricing plan must be Basic.
* Dockerfile already exists under `/root/pyapp` directory on azure-client host.
* Build a Docker image using this Dockerfile and push the same to the newly created ACR repo. The image tag must be latest i.e `xfusionacr3932:latest`.