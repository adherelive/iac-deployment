# Azure Deployment Guide for AdhereLive

This guide walks you through deploying the AdhereLive application stack on Microsoft Azure using Terraform.

**CURRENT STATUS: NOT FUNCTIONAL**

The Azure deployment is not yet functional. The Terraform configuration files in this directory (`azure/`) are currently incorrect and are copies of the AWS configuration. Before you can deploy to Azure, you must replace them with a valid Azure Terraform configuration.

## How to Deploy (Once Corrected)

Once the Terraform files in this directory have been corrected, you can use the root-level `deploy.sh` script to manage your Azure infrastructure.

### Prerequisites

1.  **Terraform**: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2.  **Azure CLI**: [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3.  A valid Azure account with the necessary permissions.

### Deployment Steps

1.  **Configure your Azure Credentials**:
    ```bash
    az login
    ```

2.  **Plan the deployment**:
    This command will initialize Terraform and show you what Azure resources will be created. Run it from the root of the repository.
    ```bash
    ./deploy.sh azure plan
    ```

3.  **Apply the configuration**:
    This will create all the necessary resources in Azure.
    ```bash
    ./deploy.sh azure apply
    ```

4.  **Destroy the infrastructure**:
    To remove all resources created by Terraform in Azure:
    ```bash
    ./deploy.sh azure destroy
    ```

## Required Corrections

To enable the Azure deployment, the following files in this directory must be created or corrected:

1.  **`main.tf`**: This file must contain the Terraform configuration for your Azure resources (e.g., Resource Groups, App Service, Azure Database for MySQL, etc.). It should use the `azurerm` provider.
2.  **`variables.tf`**: This file should define all the variables used in your Azure configuration.
3.  **`outputs.tf`**: This file should define any outputs from your Azure deployment, such as application URLs or database hostnames.
4.  **`deploy-infrastructure.sh`**: The placeholder script in this directory must be replaced with a script capable of running `terraform` commands for the Azure environment, similar to the one in the `aws/` directory.

Once these corrections are made, the `./deploy.sh azure` command will become fully functional.