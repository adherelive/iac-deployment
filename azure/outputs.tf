# outputs.tf

output "frontend_public_ip" {
  description = "The public IP address of the frontend VM."
  value       = azurerm_public_ip.frontend_pip.ip_address
}

output "backend_public_ip" {
  description = "The public IP address of the backend VM."
  value       = azurerm_public_ip.backend_pip.ip_address
}

output "frontend_public_fqdn" {
  description = "The fully qualified domain name of the frontend VM."
  value       = azurerm_public_ip.frontend_pip.fqdn
}

output "backend_public_fqdn" {
  description = "The fully qualified domain name of the backend VM."
  value       = azurerm_public_ip.backend_pip.fqdn
}

output "mysql_hostname" {
  description = "The hostname of the Azure Database for MySQL server."
  value       = azurerm_mysql_server.main.fqdn
}

output "redis_hostname" {
  description = "The hostname of the Azure Cache for Redis instance."
  value       = azurerm_redis_cache.main.hostname
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}
