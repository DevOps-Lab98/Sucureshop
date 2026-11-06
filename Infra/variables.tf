variable "resource_group_name" {
  description = "Azure Resource Group ka naam"
  type        = string
  default     = "rg-secureshop-prod"
}

variable "location" {
  description = "Azure Region / Location"
  type        = string
  default     = "centralindia"
}

variable "vnet_name" {
  description = "Virtual Network ka naam"
  type        = string
  default     = "vnet-secureshop"
}

variable "vnet_address_space" {
  description = "VNet ka CIDR address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# --- Subnet 1: AKS ---
variable "aks_subnet_name" {
  description = "AKS ke liye Subnet ka naam"
  type        = string
  default     = "snet-aks"
}

variable "aks_subnet_address_prefix" {
  description = "AKS Subnet ka CIDR range"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

# --- Subnet 2: Private Endpoints (ACR, Key Vault, Storage, Database) ---
variable "pe_subnet_name" {
  description = "Private Endpoints (ACR, Key Vault, Storage, SQL DB) ke liye Subnet ka naam"
  type        = string
  default     = "snet-private-endpoints"
}

variable "pe_subnet_address_prefix" {
  description = "Private Endpoints Subnet ka CIDR range"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

# --- AKS Cluster ---
variable "aks_cluster_name" {
  description = "AKS Cluster ka naam"
  type        = string
  default     = "aks-secureshop"
}

variable "aks_dns_prefix" {
  description = "AKS DNS Prefix"
  type        = string
  default     = "secureshop-k8s"
}

variable "aks_node_count" {
  description = "Default node pool ke node count"
  type        = number
  default     = 1
}

variable "aks_node_vm_size" {
  description = "AKS Worker Nodes ka VM Size"
  type        = string
  default     = "Standard_D2s_v4"
}

# --- ACR ---
variable "acr_name_prefix" {
  description = "ACR ka prefix (globally unique banega random suffix ke sath)"
  type        = string
  default     = "secureshopacr"
}

# --- Azure Key Vault ---
variable "key_vault_name_prefix" {
  description = "Azure Key Vault ka prefix (globally unique banega)"
  type        = string
  default     = "secureshop-kv"
}

# --- Azure Storage Account ---
variable "storage_account_prefix" {
  description = "Storage Account ka prefix (globally unique lowercase alphanumeric)"
  type        = string
  default     = "secureshopstore"
}

# --- Azure SQL Database ---
variable "sql_server_prefix" {
  description = "Azure SQL Server ka prefix"
  type        = string
  default     = "secureshop-sql"
}

variable "sql_database_name" {
  description = "Azure SQL Database ka naam"
  type        = string
  default     = "secureshopdb"
}

variable "sql_admin_username" {
  description = "Azure SQL Server administrator username"
  type        = string
  default     = "sqladminuser"
}
