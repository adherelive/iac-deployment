terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment this section if you want to use Azure Storage for state management
  backend "azurerm" {
    resource_group_name  = "adherelive-terraform-state-rg"
    storage_account_name = "adherelivestfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}