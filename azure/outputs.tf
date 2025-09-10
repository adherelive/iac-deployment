# outputs.tf

output "frontend_app_service_url" {
  description = "The URL of the frontend App Service."
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "backend_app_service_url" {
  description = "The URL of the backend App Service."
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "mysql_flexible_server_fqdn" {
  description = "The FQDN of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "container_registry_login_server" {
  description = "The login server for the Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}
