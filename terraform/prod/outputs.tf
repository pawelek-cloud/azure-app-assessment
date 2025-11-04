output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "acr_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "app_name" {
  description = "The name of the deployed Web App"
  value       = azurerm_linux_web_app.web_app.name
}

output "app_url" {
  description = "The default hostname of the Web App"
  value       = azurerm_linux_web_app.web_app.default_hostname
}
output "random_suffix" {
  value = random_id.suffix.hex
}

output "db_host" {
  description = "The fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}


