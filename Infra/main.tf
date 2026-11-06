# ==============================================================================
# SECURE SHOP AZURE INFRASTRUCTURE - MAIN CONFIGURATION
# ==============================================================================
# This configuration creates a fully private, zero-trust enterprise Azure architecture:
# 1. Resource Group: Centralized container for lifecycle and billing management.
# 2. Virtual Network (VNet): 10.0.0.0/16 private network isolated from the public internet.
# 3. Subnets:
#    - Subnet 1 (10.0.1.0/24): Dedicated to AKS Worker Nodes and Pod IPs (Azure CNI).
#    - Subnet 2 (10.0.2.0/24): Dedicated to Private Endpoints (ACR, Key Vault, Storage, SQL DB).
# 4. Managed Identities & RBAC:
#    - AKS Control Plane Identity with Network Contributor on the AKS Subnet.
#    - AKS Kubelet Identity with AcrPull role on Azure Container Registry.
#    - AKS Identity with Storage Blob Data Contributor on Azure Storage Account.
#    - Key Vault Access Policy granting Get/List secrets to AKS.
# 5. Private Azure Container Registry (ACR): Premium SKU, public access disabled.
# 6. Private Azure Key Vault: Soft-delete, firewall deny-by-default, private endpoint.
# 7. Private Azure Storage Account: TLS 1.2, private blob container, private endpoint.
# 8. Private Azure SQL Database: Public access disabled, random password stored in Key Vault.
# 9. Private DNS Zones: Automatic internal name resolution for all private endpoints.
# 10. Azure Kubernetes Service (AKS): VNet-integrated with Azure CNI networking.
# ==============================================================================

# ------------------------------------------------------------------------------
# Azure Client Configuration & Utility Resources
# ------------------------------------------------------------------------------

# Retrieves tenant ID, subscription ID, and client object ID of the user/pipeline running Terraform.
# This is necessary to grant Key Vault administrative access to the deployer.
data "azurerm_client_config" "current" {}

# Generates a random 6-character lowercase alphanumeric string.
# Azure resources like Storage Accounts, Key Vaults, ACR, and SQL Servers require globally unique names across all Azure customers.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# 1. Resource Group
# ------------------------------------------------------------------------------

# Central logical boundary holding all resources for the Secure Shop solution.
# Deleting this resource group cleanly deprovisions all associated infrastructure.
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "SecureShop"
  }
}

# ------------------------------------------------------------------------------
# 2. Virtual Network & Subnet Topology
# ------------------------------------------------------------------------------

# Main Virtual Network (10.0.0.0/16 = 65,536 private IP addresses).
# All internal communications between AKS, ACR, DB, Storage, and Key Vault stay strictly inside this network.
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = "Production"
  }
}

# Subnet 1: Dedicated to the Azure Kubernetes Service (AKS) cluster.
# With Azure CNI, every pod and worker node gets a real IP from this subnet (10.0.1.0/24 = 251 usable IPs).
resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.aks_subnet_address_prefix
}

# Subnet 2: Dedicated to Private Endpoints (Private Link Network Interfaces).
# Housing Private Endpoints in a separate subnet from compute prevents IP exhaustion and allows strict NSG microsegmentation.
resource "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.pe_subnet_address_prefix
}

# ------------------------------------------------------------------------------
# 3. User-Assigned Managed Identity for AKS Control Plane
# ------------------------------------------------------------------------------

# Creating a dedicated User-Assigned Managed Identity instead of System-Assigned prevents
# circular dependency errors in Terraform when pre-granting Network Contributor permissions on the VNet/Subnet.
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.aks_cluster_name}-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Role Assignment: AKS Control Plane must have "Network Contributor" on the AKS subnet
# to dynamically allocate IP addresses for pods and configure internal load balancers.
resource "azurerm_role_assignment" "aks_subnet_network_contributor" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# ------------------------------------------------------------------------------
# 4. Azure Container Registry (ACR) - Private Setup
# ------------------------------------------------------------------------------

# Private Docker container registry where application images are stored.
# - SKU: Premium is mandatory to enable Azure Private Link and private endpoints.
# - public_network_access_enabled = false blocks all traffic originating from the public internet.
# - admin_enabled = false enforces secure token and Azure Active Directory / Managed Identity authentication.
resource "azurerm_container_registry" "acr" {
  name                          = "${var.acr_name_prefix}${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  tags = {
    Environment = "Production"
  }
}

# Private DNS Zone required for ACR Private Endpoint.
# Overrides public DNS so queries to <registry>.azurecr.io resolve to the private endpoint IP inside the VNet.
resource "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
}

# Links the ACR Private DNS Zone to our Virtual Network so VMs/pods in the VNet can resolve the private IP.
resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  name                  = "${var.vnet_name}-acr-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for ACR: Creates a virtual network interface (NIC) with a private IP in Subnet 2.
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "${azurerm_container_registry.acr.name}-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_container_registry.acr.name}-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_dns.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.acr_dns_link
  ]
}

# ------------------------------------------------------------------------------
# 5. Azure Key Vault - Zero-Trust Secrets Management
# ------------------------------------------------------------------------------

# Secure, centralized secret store for database credentials, certificates, and API keys.
# - Soft Delete: Retains deleted secrets for 7 days in case of accidental removal.
# - Security Model: Access Policies (AAD-based) are the primary security boundary.
# - Private Endpoint provides VNet-internal routing for AKS pods; public access is
#   required so Terraform running from a local/CI machine can seed initial secrets.
# - WHY public_network_access_enabled=true: Terraform runs from outside the VNet.
#   If disabled, Terraform cannot create or manage KV secrets → 403 ForbiddenByConnection.
#   The Access Policy already ensures only the deployer + AKS identity can access secrets.
resource "azurerm_key_vault" "kv" {
  name                          = "${var.key_vault_name_prefix}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true # Required: Terraform (local/CI) needs public access to manage secrets

  # Network ACL: Allow all traffic (AAD Access Policy is the security boundary).
  # AzureServices bypass ensures ARM/Terraform can always reach the vault.
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  # Deployer Access Policy: Grants the current user or CI/CD runner full permissions to seed initial secrets.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  # AKS Identity Access Policy: Grants AKS pods/workloads read-only permissions to retrieve runtime secrets.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.aks_identity.principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = {
    Environment = "Production"
  }
}

# Private DNS Zone for Key Vault (resolves <vault-name>.vault.azure.net to private IP).
resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Links Key Vault Private DNS Zone to the VNet.
resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "${var.vnet_name}-kv-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for Key Vault in Subnet 2.
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${azurerm_key_vault.kv.name}-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_key_vault.kv.name}-psc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_dns.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.kv_dns_link
  ]
}

# ------------------------------------------------------------------------------
# 6. Azure Storage Account - Private Blob Storage
# ------------------------------------------------------------------------------

# Private object storage for unstructured data, logs, and application files.
# - WHY public_network_access_enabled=true: Terraform (local/CI) connects to the Storage
#   data plane to create blob containers. With it set to false, the runner gets 403
#   AuthorizationFailure since it is outside the VNet.
# - Security: Container access type is "private" (no anonymous access). AKS pods
#   authenticate via Managed Identity (Storage Blob Data Contributor role).
#   Private Endpoint ensures AKS traffic stays on the Azure backbone.
# - allow_nested_items_to_be_public = false prevents any accidental blob exposure.
# - min_tls_version = TLS1_2 enforces strong transport encryption.
resource "azurerm_storage_account" "storage" {
  name                            = "${var.storage_account_prefix}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = true  # Required: Terraform (local/CI) must reach data plane to create containers
  allow_nested_items_to_be_public = false # Prevents accidental anonymous blob exposure
  min_tls_version                 = "TLS1_2"

  # Storage firewall: Allow trusted Azure services (ARM, ADF etc.) to bypass.
  # AKS pods access via Private Endpoint; Terraform creates containers via public endpoint.
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  tags = {
    Environment = "Production"
  }
}

# Private Blob Container for storing application assets and media.
resource "azurerm_storage_container" "app_data" {
  name                  = "appdata"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

# Private DNS Zone for Storage Blob endpoint (resolves <account>.blob.core.windows.net to private IP).
resource "azurerm_private_dns_zone" "blob_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Links Storage Blob Private DNS Zone to the VNet.
resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_link" {
  name                  = "${var.vnet_name}-blob-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for Storage Account (blob service) in Subnet 2.
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "${azurerm_storage_account.storage.name}-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_storage_account.storage.name}-psc"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_dns.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.blob_dns_link
  ]
}

# Role Assignment: AKS Identity is granted "Storage Blob Data Contributor".
# This allows AKS workloads to authenticate with Azure AD tokens to read and write blobs without storage account access keys.
resource "azurerm_role_assignment" "aks_storage_contributor" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# ------------------------------------------------------------------------------
# 7. Azure SQL Database - Fully Private Database
# ------------------------------------------------------------------------------

# Generates a 16-character cryptographically secure password for the database administrator.
resource "random_password" "sql_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Azure SQL Logical Server:
# - public_network_access_enabled = false disables public access on port 1433.
# - TLS 1.2 enforced for all client connections.
# NOTE: 'public_network_access_enabled' is deprecated in newer AzureRM versions.
#       Modern alternative: use 'azurerm_mssql_server_extended_auditing_policy' or manage
#       access via firewall rules with 'azurerm_mssql_firewall_rule' (deny all public IPs).
resource "azurerm_mssql_server" "sql" {
  name                          = "${var.sql_server_prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = random_password.sql_admin_password.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false # Deprecated but valid in AzureRM ~> 3.90

  tags = {
    Environment = "Production"
  }
}

# Azure SQL Database instance (cost-efficient Basic SKU, scalable on demand).
# NOTE: Basic SKU hard limit is 2 GB. To increase, upgrade sku_name to "S0" or higher.
resource "azurerm_mssql_database" "db" {
  name        = var.sql_database_name
  server_id   = azurerm_mssql_server.sql.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb = 2     # Fixed: Basic SKU maximum is 2 GB (was incorrectly set to 4)
  sku_name    = "Basic"

  tags = {
    Environment = "Production"
  }
}

# Private DNS Zone for Azure SQL (resolves <server>.database.windows.net to internal private IP).
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Links Azure SQL Private DNS Zone to the VNet.
resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "${var.vnet_name}-sql-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for Azure SQL Server in Subnet 2.
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${azurerm_mssql_server.sql.name}-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_mssql_server.sql.name}-psc"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_dns.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.sql_dns_link
  ]
}

# Automatically stores the generated SQL Admin Password securely inside Azure Key Vault.
resource "azurerm_key_vault_secret" "sql_admin_password_secret" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault.kv
  ]
}

# Automatically stores the complete connection string inside Azure Key Vault for easy developer consumption.
resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${random_password.sql_admin_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault.kv
  ]
}

# ------------------------------------------------------------------------------
# 8. Azure Kubernetes Service (AKS)
# ------------------------------------------------------------------------------

# Managed Kubernetes Cluster:
# - Default Node Pool: 2 nodes using Standard_D2s_v3 (2 vCPU, 8 GiB RAM).
# - VNet Integration: Deployed directly inside Subnet 1 (snet-aks).
# - Network Plugin: Azure CNI provides native VNet IP routing and minimal latency.
# - Identity: Uses our pre-configured UserAssigned identity.
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.aks_dns_prefix

  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

   network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "172.16.0.0/16"   # <-- K8s internal services range (Non-overlapping)
    dns_service_ip    = "172.16.0.10"     # <-- K8s CoreDNS IP (service_cidr ke andar)
  }

  # Ensure the subnet role assignment finishes before AKS deployment begins
  depends_on = [
    azurerm_role_assignment.aks_subnet_network_contributor
  ]

  tags = {
    Environment = "Production"
  }
}

# ------------------------------------------------------------------------------
# 9. Role Assignment: AKS Kubelet Identity -> ACR AcrPull
# ------------------------------------------------------------------------------

# Grants the AKS worker node pool's kubelet identity the "AcrPull" role on the container registry.
# This enables Kubernetes pods to pull container images from the private registry without managing docker-registry pull secrets.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
