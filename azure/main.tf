# main.tf for Azure - Modernized with App Service

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  # List of backend secret names to be referenced from Key Vault.
  # The pipeline is expected to create secrets in Key Vault with the 'be-' prefix.
  # Example: 'be-MONGO_DB_URI', 'be-TOKEN_SECRET_KEY', etc.
  backend_secret_keys = [
    "MONGO_DB_URI",
    "TOKEN_SECRET_KEY",
    "TWILIO_ACCOUNT_SID",
    "TWILIO_API_KEY",
    "TWILIO_API_SECRET",
    "TWILIO_CHAT_SERVICE_SID",
    "TWILIO_AUTH_TOKEN",
    "GETSTREAM_API_KEY",
    "GETSTREAM_API_SECRET",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "SENDGRID_API_KEY",
    "RAZORPAY_KEY",
    "RAZORPAY_SECRET",
    "ALGOLIA_BACKEND_KEY",
    "AGORA_APP_CERTIFICATE",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "S3_ACCESS_KEY",
    "S3_SECRET_KEY",
    "ONE_SIGNAL_KEY"
    # Add any other required secret keys here
  ]

  # Create a map of app settings for the backend, dynamically generating Key Vault references.
  backend_app_settings_from_kv = {
    for key in local.backend_secret_keys : key => "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.main.vault_uri}secrets/be-${key}/)"
  }
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# --- Networking ---

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "adherelive-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Subnet for App Service Integration
resource "azurerm_subnet" "app_service_subnet" {
  name                 = "app-service-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Database Private Endpoint
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  private_endpoint_network_policies_enabled = true
}

# --- Container Registry ---
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = true # Needed for the pipeline to easily log in
}

# --- Database (MySQL Flexible Server) ---

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "${var.mysql_server_name}-${var.environment}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "8.0.21"
  sku_name               = var.mysql_sku_name
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  storage_mb             = 20480 # 20 GB
  zone                   = "1" # Set availability zone

  # Disable public access
  public_network_access_enabled = false

  backup_retention_days = 7
}

# Private DNS Zone for MySQL
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${azurerm_virtual_network.main.name}-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# --- App Service Plan ---
resource "azurerm_service_plan" "main" {
  name                = "adherelive-asp"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "P1v2" # Premium plan for VNet integration
}

# --- Key Vault ---
resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  # Access for the user/principal running Terraform
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}

# --- App Services ---

# Frontend App Service
resource "azurerm_linux_web_app" "frontend" {
  name                = "adherelive-fe-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      docker_image     = "${azurerm_container_registry.main.login_server}/${var.frontend_image_name}"
      docker_image_tag = var.image_tag
    }
    always_on = true
  }

  identity {
    type = "SystemAssigned"
  }

  # Connect to VNet
  virtual_network_subnet_id = azurerm_subnet.app_service_subnet.id

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL"      = "https://${azurerm_container_registry.main.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.main.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.main.admin_password
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  https_only = true
}

# Backend App Service
resource "azurerm_linux_web_app" "backend" {
  name                = "adherelive-be-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      docker_image     = "${azurerm_container_registry.main.login_server}/${var.backend_image_name}"
      docker_image_tag = var.image_tag
    }
    always_on = true
  }

  identity {
    type = "SystemAssigned"
  }

  # Connect to VNet
  virtual_network_subnet_id = azurerm_subnet.app_service_subnet.id

  # App settings are a combination of static values and dynamic Key Vault references
  app_settings = merge(
    {
      "DOCKER_REGISTRY_SERVER_URL"      = "https://${azurerm_container_registry.main.login_server}"
      "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.main.admin_username
      "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.main.admin_password
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
      "DB_HOST"                         = azurerm_mysql_flexible_server.main.fqdn
      "DB_USER"                         = var.mysql_admin_username
      "DB_PASSWORD"                     = var.mysql_admin_password
      "DB_DATABASE"                     = "adhere"
      "APP_ENV"                         = var.environment
      "NODE_ENV"                        = var.environment
    },
    local.backend_app_settings_from_kv
  )

  https_only = true
}

# --- Key Vault Access Policies for App Services ---

resource "azurerm_key_vault_access_policy" "frontend_app_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_web_app.frontend.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.frontend.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "backend_app_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_web_app.backend.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.backend.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
