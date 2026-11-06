terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # AzureRM v4.x uses stable GA API versions for AKS (Microsoft.ContainerService).
      # AzureRM v3.x hardcoded '2023-06-02-preview' which Microsoft permanently retired in 2025.
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  # In AzureRM v4, resource provider registration is explicitly controlled.
  # "none" avoids permission errors during provider initialization.
  resource_provider_registrations = "none"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
