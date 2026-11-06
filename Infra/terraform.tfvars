# ==============================================================================
# SECURE SHOP INFRASTRUCTURE - TERRAFORM VARIABLES (LOCAL CONFIG)
# ==============================================================================

# General / Resource Group Configuration
resource_group_name = "rg-secureshop-prod"
location            = "centralindia"

# Virtual Network & Subnets
vnet_name          = "vnet-secureshop"
vnet_address_space = ["10.0.0.0/16"]

aks_subnet_name           = "snet-aks"
aks_subnet_address_prefix = ["10.0.1.0/24"]

pe_subnet_name           = "snet-private-endpoints"
pe_subnet_address_prefix = ["10.0.2.0/24"]

# AKS Cluster Configuration
aks_cluster_name = "aks-secureshop"
aks_dns_prefix   = "secureshop-k8s"
aks_node_count   = 1
aks_node_vm_size = "Standard_D2s_v4"

# Azure Container Registry (ACR)
acr_name_prefix = "secureshopacr"

# Azure Key Vault
key_vault_name_prefix = "secureshop-kv"

# Azure Storage Account
storage_account_prefix = "secureshopstore"

# Azure SQL Database Configuration
sql_server_prefix  = "secureshop-sql"
sql_database_name  = "secureshopdb"
sql_admin_username = "sqladminuser"

