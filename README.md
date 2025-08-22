# AdhereLive Infrastructure as Code

This repository contains the Infrastructure as Code (IaC) for the AdhereLive application, managed with Terraform. It provides a unified way to deploy the necessary infrastructure to both AWS and Microsoft Azure.

## Quick Start

The primary way to deploy and manage the infrastructure is through the root-level `deploy.sh` script. This script is a wrapper that handles the specifics of deploying to different cloud providers.

### Prerequisites

Before you begin, ensure you have the following installed on your local machine:
1.  **Terraform**: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2.  **Cloud Provider CLI**:
    *   For AWS: **AWS CLI** ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
    *   For Azure: **Azure CLI** ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))

### Usage

The `deploy.sh` script is located in the root of this repository. To use it, run the following command:

```bash
./deploy.sh [provider] [action]
```

**Providers:**
*   `aws`: Deploys the infrastructure to Amazon Web Services.
*   `azure`: Deploys the infrastructure to Microsoft Azure.

**Actions:**
*   `init`: Initializes Terraform for the selected provider.
*   `plan`: (Default) Creates a Terraform execution plan.
*   `apply`: Applies the Terraform plan to create the infrastructure.
*   `destroy`: Destroys the Terraform-managed infrastructure.

### Example: Deploying to AWS

1.  **Configure your AWS Credentials**:
    ```bash
    aws configure
    ```

2.  **Plan the deployment**:
    This command will initialize Terraform and show you what resources will be created.
    ```bash
    ./deploy.sh aws plan
    ```

3.  **Apply the configuration**:
    This will create all the necessary resources in AWS.
    ```bash
    ./deploy.sh aws apply
    ```

## Deployment Status

### AWS Deployment

The AWS deployment is fully configured and ready to be deployed. It uses a modular Terraform structure to create a robust and scalable environment in ECS Fargate.

For more detailed information, see the [AWS Implementation Guide](./aws/implementation-guide.md).

### Azure Deployment

**The Azure deployment is not yet functional.** The Terraform files in the `azure/` directory are currently incorrect copies of the AWS configuration.

To make the Azure deployment functional, you will need to:
1.  Replace the files in the `azure/` directory with the correct Terraform configuration for Azure.
2.  Ensure you have a `deploy-infrastructure.sh` script within the `azure/` directory that can execute the Terraform commands.

Once the configuration is corrected, you can deploy to Azure using the standard command:
```bash
./deploy.sh azure apply
```

For more details, see the [Azure Deployment Guide](./azure/DeploymentGuide.md).