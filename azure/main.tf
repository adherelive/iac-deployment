# main.tf for Azure

locals {
  frontend_secrets = {
    "fe-SKIP_PREFLIGHT_CHECK"                = "true",
    "fe-REACT_APP_ENV"                       = var.environment,
    "fe-WEB_SERVER_PORT"                     = "80",
    "fe-REACT_SERVER_PORT"                   = "3000",
    "fe-REACT_APP_WEB_URL"                   = "https://${azurerm_public_ip.frontend_pip.fqdn}",
    "fe-REACT_APP_API_BASE_URL"              = "https://${azurerm_public_ip.backend_pip.fqdn}/api",
    "fe-REACT_APP_BACKEND_URL"               = "https://${azurerm_public_ip.backend_pip.fqdn}/api",
    "fe-REACT_APP_GETSTREAM_API_KEY"         = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_GETSTREAM_API_SECRET"      = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_GETSTREAM_APP_ID"          = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_TWILIO_CHANNEL_SERVER"     = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_ALGOLIA_APP_ID"            = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_ALGOLIA_APP_KEY"           = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_MEDICINE_INDEX"            = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_ADHERE_LIVE_CONTACT_LINK"  = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_LOGIN_CONTACT_MESSAGE"     = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_VERIFICATION_PENDING_MESSAGE" = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_ADMIN_MEDICINE_ONE_PAGE_LIMIT" = "10",
    "fe-REACT_APP_AGORA_APP_ID"              = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_NOTIFICATION_ONE_TIME_LIMIT" = "10",
    "fe-REACT_APP_FIREBASE_CHANNEL"          = "PLEASE-SET-THIS-VALUE",
    "fe-REACT_APP_DEBUG_IMAGES"              = "true",
    "fe-REACT_APP_DEBUG_LOGS"                = "true",
    "fe-REACT_APP_LOG_LEVEL"                 = "3",
    "fe-REACT_APP_LOG_ENDPOINT"              = "https://${azurerm_public_ip.backend_pip.fqdn}/api/logs",
    "fe-REACT_APP_S3_BASE_URL"               = "PLEASE-SET-THIS-VALUE",
  }

  backend_secrets = {
    "be-APP_KEY"                             = "PLEASE-SET-THIS-VALUE",
    "be-APP_ENV"                             = var.environment,
    "be-NODE_ENV"                            = var.environment,
    "be-APP_NAME"                            = "adherelive",
    "be-API_URL"                             = "https://${azurerm_public_ip.backend_pip.fqdn}",
    "be-WEB_URL"                             = "https://${azurerm_public_ip.frontend_pip.fqdn}",
    "be-APP_URL"                             = "https://${azurerm_public_ip.backend_pip.fqdn}",
    "be-DB_HOST"                             = azurerm_mysql_server.main.fqdn,
    "be-DB_USER"                             = var.mysql_admin_username,
    "be-DB_PASSWORD"                         = var.mysql_admin_password,
    "be-DB_DATABASE"                         = "adhere",
    "be-MONGO_DB_URI"                        = "PLEASE-SET-MONGO-DB-URI",
    "be-REDIS_HOST"                          = azurerm_redis_cache.main.hostname,
    "be-REDIS_PORT"                          = azurerm_redis_cache.main.ssl_port,
    "be-REDIS_PASSWORD"                      = azurerm_redis_cache.main.primary_access_key,
    "be-GITHUB_SSH_PRIVATE_KEY"              = "PLEASE-SET-GITHUB-PRIVATE-KEY",
    "be-APP_PORT"                            = "5000",
    "be-TOKEN_SECRET_KEY"                    = "PLEASE-SET-THIS-VALUE",
    "be-TWILIO_ACCOUNT_SID"                  = "PLEASE-SET-THIS-VALUE",
    "be-TWILIO_API_KEY"                      = "PLEASE-SET-THIS-VALUE",
    "be-TWILIO_API_SECRET"                   = "PLEASE-SET-THIS-VALUE",
    "be-TWILIO_CHAT_SERVICE_SID"             = "PLEASE-SET-THIS-VALUE",
    "be-TWILIO_AUTH_TOKEN"                   = "PLEASE-SET-THIS-VALUE",
    "be-GETSTREAM_API_KEY"                   = "PLEASE-SET-THIS-VALUE",
    "be-GETSTREAM_API_SECRET"                = "PLEASE-SET-THIS-VALUE",
    "be-GOOGLE_CLIENT_ID"                    = "PLEASE-SET-THIS-VALUE",
    "be-GOOGLE_CLIENT_SECRET"                = "PLEASE-SET-THIS-VALUE",
    "be-SENDGRID_API_KEY"                    = "PLEASE-SET-THIS-VALUE",
    "be-RAZORPAY_KEY"                        = "PLEASE-SET-THIS-VALUE",
    "be-RAZORPAY_SECRET"                     = "PLEASE-SET-THIS-VALUE",
    "be-ALGOLIA_BACKEND_KEY"                 = "PLEASE-SET-THIS-VALUE",
    "be-AGORA_APP_CERTIFICATE"               = "PLEASE-SET-THIS-VALUE",
    "be-AWS_ACCESS_KEY_ID"                   = "PLEASE-SET-THIS-VALUE",
    "be-AWS_SECRET_ACCESS_KEY"               = "PLEASE-SET-THIS-VALUE",
    "be-S3_ACCESS_KEY"                       = "PLEASE-SET-THIS-VALUE",
    "be-S3_SECRET_KEY"                       = "PLEASE-SET-THIS-VALUE",
    "be-MINIO_ACCESS_KEY"                    = "PLEASE-SET-THIS-VALUE",
    "be-MINIO_SECRET_KEY"                    = "PLEASE-SET-THIS-VALUE",
    "be-ONE_SIGNAL_KEY"                      = "PLEASE-SET-THIS-VALUE",
    "be-FACEBOOK_APP_TOKEN"                  = "PLEASE-SET-THIS-VALUE",
    "be-FACEBOOK_SECRET_TOKEN"               = "PLEASE-SET-THIS-VALUE",
    "be-BRANCH_IO_KEY"                       = "PLEASE-SET-THIS-VALUE",
    "be-SMS_BAZAR_PASSWORD"                  = "PLEASE-SET-THIS-VALUE"
  }

  all_secrets = merge(local.frontend_secrets, local.backend_secrets)
}

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

# Public Subnet for VMs
resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet for Database and Redis
resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"] # For Azure SQL
}

# --- Network Security Groups ---

# NSG for Frontend VM
resource "azurerm_network_security_group" "frontend_nsg" {
  name                = "frontend-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for Backend VM
resource "azurerm_network_security_group" "backend_nsg" {
  name                = "backend-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AppPort"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = azurerm_subnet.public.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

# --- Public IPs ---

resource "azurerm_public_ip" "frontend_pip" {
  name                = "frontend-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "backend_pip" {
  name                = "backend-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- Network Interfaces ---

resource "azurerm_network_interface" "frontend_nic" {
  name                = "frontend-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.frontend_pip.id
  }
}

resource "azurerm_network_interface" "backend_nic" {
  name                = "backend-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.backend_pip.id
  }
}

# Associate NSGs with NICs
resource "azurerm_network_interface_security_group_association" "frontend_nic_nsg" {
  network_interface_id      = azurerm_network_interface.frontend_nic.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}

resource "azurerm_network_interface_security_group_association" "backend_nic_nsg" {
  network_interface_id      = azurerm_network_interface.backend_nic.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

# --- Databases and Cache ---

# Azure Database for MySQL
resource "azurerm_mysql_server" "main" {
  name                = "${var.mysql_server_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku_name = var.mysql_sku_name

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = var.mysql_admin_username
  administrator_login_password = var.mysql_admin_password
  version                      = "5.7"
  ssl_enforcement_enabled      = true
}

# MySQL Virtual Network Rule
resource "azurerm_mysql_virtual_network_rule" "main" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.main.name
  subnet_id           = azurerm_subnet.private.id
}

# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "${var.redis_cache_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku_name            = var.redis_sku_name
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {}

  subnet_id = azurerm_subnet.private.id
}

# --- Secrets Management ---

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_key_vault_secret" "app_secrets" {
  for_each     = local.all_secrets
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id
}

# --- Virtual Machines ---

# Frontend VM
resource "azurerm_linux_virtual_machine" "frontend" {
  name                = "frontend-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.frontend_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-LTS"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.tpl", {
    key_vault_name       = azurerm_key_vault.main.name
    git_repo_url         = var.github_repo_fe
    app_name             = "frontend"
    app_port             = "80"
    nginx_conf_content   = file("${path.module}/nginx.conf")
  }))
}

# Backend VM
resource "azurerm_linux_virtual_machine" "backend" {
  name                = "backend-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.backend_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-LTS"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.tpl", {
    key_vault_name       = azurerm_key_vault.main.name
    git_repo_url         = var.github_repo_be
    app_name             = "backend"
    app_port             = "5000"
    nginx_conf_content   = "" # Not needed for backend
  }))
}

# --- Key Vault Access Policies for VMs ---

resource "azurerm_key_vault_access_policy" "frontend_vm_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_virtual_machine.frontend.identity[0].tenant_id
  object_id    = azurerm_linux_virtual_machine.frontend.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

resource "azurerm_key_vault_access_policy" "backend_vm_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_virtual_machine.backend.identity[0].tenant_id
  object_id    = azurerm_linux_virtual_machine.backend.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}
