# --- Resource Group & Networking Outputs ---
output "resource_group_name" {
  description = "Created Resource Group ka naam"
  value       = azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "Created VNet ka naam"
  value       = azurerm_virtual_network.vnet.name
}

output "aks_subnet_id" {
  description = "AKS Subnet ID"
  value       = azurerm_subnet.aks.id
}

output "pe_subnet_id" {
  description = "Private Endpoints Subnet ID"
  value       = azurerm_subnet.pe.id
}

# --- AKS Outputs ---
output "aks_cluster_name" {
  description = "AKS Cluster ka naam"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_get_credentials_command" {
  description = "Kubectl config setup karne ke liye command"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

# --- ACR Outputs ---
output "acr_name" {
  description = "Azure Container Registry ka naam"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "ACR ka Login Server endpoint"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_private_ip" {
  description = "ACR Private Endpoint ka internal IP address"
  value       = azurerm_private_endpoint.acr_pe.private_service_connection[0].private_ip_address
}

# --- Key Vault Outputs ---
output "key_vault_name" {
  description = "Azure Key Vault ka naam"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "Azure Key Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "key_vault_private_ip" {
  description = "Key Vault Private Endpoint ka internal IP"
  value       = azurerm_private_endpoint.kv_pe.private_service_connection[0].private_ip_address
}

# --- Storage Account Outputs ---
output "storage_account_name" {
  description = "Azure Storage Account ka naam"
  value       = azurerm_storage_account.storage.name
}

output "storage_container_name" {
  description = "Blob Container ka naam"
  value       = azurerm_storage_container.app_data.name
}

output "storage_private_ip" {
  description = "Storage Account Private Endpoint ka internal IP"
  value       = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
}

# --- Azure SQL Database Outputs ---
output "sql_server_fqdn" {
  description = "Azure SQL Server FQDN"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Azure SQL Database ka naam"
  value       = azurerm_mssql_database.db.name
}

output "sql_private_ip" {
  description = "Azure SQL Server Private Endpoint ka internal IP"
  value       = azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address
}
