provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "adherelive" {
  name     = var.resource_group_name
  location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
}

# Create subnets
resource "azurerm_subnet" "backend_subnet" {
  name                 = "${var.prefix}-backend-subnet"
  resource_group_name  = azurerm_resource_group.adherelive.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "frontend_subnet" {
  name                 = "${var.prefix}-frontend-subnet"
  resource_group_name  = azurerm_resource_group.adherelive.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "database_subnet" {
  name                 = "${var.prefix}-database-subnet"
  resource_group_name  = azurerm_resource_group.adherelive.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.AzureCosmosDB"]
}

# Create Network Security Groups
resource "azurerm_network_security_group" "backend_nsg" {
  name                = "${var.prefix}-backend-nsg"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Backend"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "frontend_nsg" {
  name                = "${var.prefix}-frontend-nsg"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
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
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "backend_nsg_association" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "frontend_nsg_association" {
  subnet_id                 = azurerm_subnet.frontend_subnet.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}

# Create public IPs
resource "azurerm_public_ip" "backend_ip" {
  name                = "${var.prefix}-backend-ip"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-backend"
}

resource "azurerm_public_ip" "frontend_ip" {
  name                = "${var.prefix}-frontend-ip"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  allocation_method   = "Static"
  domain_name_label   = var.prefix
}

# Create network interfaces
resource "azurerm_network_interface" "backend_nic" {
  name                = "${var.prefix}-backend-nic"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.backend_ip.id
  }
}

resource "azurerm_network_interface" "frontend_nic" {
  name                = "${var.prefix}-frontend-nic"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.frontend_ip.id
  }
}

# Create MySQL server
resource "azurerm_mysql_server" "mysql" {
  name                = "${var.prefix}-mysql"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name

  administrator_login          = "mysqladmin"
  administrator_login_password = var.mysql_admin_password

  sku_name   = "B_Gen5_1"
  storage_mb = 5120
  version    = "8.0"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

# Create MySQL database
resource "azurerm_mysql_database" "adhere" {
  name                = "adhere"
  resource_group_name = azurerm_resource_group.adherelive.name
  server_name         = azurerm_mysql_server.mysql.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# Create MySQL firewall rule for backend server
resource "azurerm_mysql_virtual_network_rule" "mysql_vnet_rule" {
  name                = "${var.prefix}-mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.adherelive.name
  server_name         = azurerm_mysql_server.mysql.name
  subnet_id           = azurerm_subnet.backend_subnet.id
}

# Create Cosmos DB account for MongoDB API
resource "azurerm_cosmosdb_account" "mongodb" {
  name                = "${var.prefix}-mongodb"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.adherelive.location
    failover_priority = 0
  }

  is_virtual_network_filter_enabled = true
  
  virtual_network_rule {
    id = azurerm_subnet.backend_subnet.id
  }
}

# Create Cosmos DB database
resource "azurerm_cosmosdb_mongo_database" "adhere_db" {
  name                = "adhere"
  resource_group_name = azurerm_resource_group.adherelive.name
  account_name        = azurerm_cosmosdb_account.mongodb.name
  throughput          = 400
}

# Create Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "${var.prefix}-redis"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  capacity            = 1
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}

# Create backend VM
resource "azurerm_linux_virtual_machine" "backend_vm" {
  name                = "${var.prefix}-backend-vm"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.backend_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/backend_init.sh", {
    mysql_host = azurerm_mysql_server.mysql.fqdn
    mysql_user = "mysqladmin"
    mysql_password = var.mysql_admin_password
    mysql_database = "adhere"
    mongodb_host = azurerm_cosmosdb_account.mongodb.connection_strings[0]
    redis_host = azurerm_redis_cache.redis.hostname
    redis_password = azurerm_redis_cache.redis.primary_access_key
    admin_username = var.admin_username
    domain_name = var.domain_name
  }))
}

# Create frontend VM
resource "azurerm_linux_virtual_machine" "frontend_vm" {
  name                = "${var.prefix}-frontend-vm"
  location            = azurerm_resource_group.adherelive.location
  resource_group_name = azurerm_resource_group.adherelive.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.frontend_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/frontend_init.sh", {
    backend_url = "http://${azurerm_public_ip.backend_ip.fqdn}:5000"
    domain_name = var.domain_name
    email = var.email
    admin_username = var.admin_username
  }))
}

# DNS Zone
resource "azurerm_dns_zone" "main" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.adherelive.name
}

# DNS A record for frontend
resource "azurerm_dns_a_record" "frontend" {
  name                = "@"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.adherelive.name
  ttl                 = 300
  records             = [azurerm_public_ip.frontend_ip.ip_address]
}

# DNS A record for API (backend)
resource "azurerm_dns_a_record" "api" {
  name                = "api"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.adherelive.name
  ttl                 = 300
  records             = [azurerm_public_ip.backend_ip.ip_address]
}

# Output the public IPs and FQDNs
output "frontend_public_ip" {
  value = azurerm_public_ip.frontend_ip.ip_address
}

output "frontend_fqdn" {
  value = azurerm_public_ip.frontend_ip.fqdn
}

output "backend_public_ip" {
  value = azurerm_public_ip.backend_ip.ip_address
}

output "backend_fqdn" {
  value = azurerm_public_ip.backend_ip.fqdn
}

output "mysql_fqdn" {
  value = azurerm_mysql_server.mysql.fqdn
}

output "cosmosdb_connection_strings" {
  value     = azurerm_cosmosdb_account.mongodb.connection_strings
  sensitive = true
}

output "redis_hostname" {
  value = azurerm_redis_cache.redis.hostname
}