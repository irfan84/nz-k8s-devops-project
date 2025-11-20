# platform-infra-iac/envs/dev/main.tf (UPDATED)

# ----------------------------------------------------
# 1. TERRAFORM CONFIGURATION (Remote State & Provider)
# ----------------------------------------------------

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-storage" 
    storage_account_name = "tfstateprodaks99"   
    container_name       = "tfstate"            
    key                  = "envs/dev/aks.terraform.tfstate" 
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "azurerm" {
  features {}
}

# ----------------------------------------------------
# 2. NETWORKING & SECURITY DEPENDENCIES (CRITICAL FOR CORPORATE SETUP)
# ----------------------------------------------------

# Resource Group to hold networking assets
resource "azurerm_resource_group" "rg_network" {
  name     = "rg-${var.project_name}-net-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_network.name
  address_space       = ["10.10.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg_network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
  
  delegations {
    name = "delegation"
    service_delays {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# --- CRITICAL: Private Cluster Requirement ---
# This ensures the internal API Server DNS name resolves within the VNet.
resource "azurerm_private_dns_zone" "aks_private_dns" {
  name                = "privatelink.${var.location}.azmk8s.io" # Standard Azure name format
  resource_group_name = azurerm_resource_group.rg_network.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "vnetlink-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg_network.name
  private_dns_zone_name = azurerm_private_dns_zone.aks_private_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# --- CRITICAL: Customer Managed Key (CMK) Resources ---
# 1. Key Vault
resource "azurerm_key_vault" "kv_cmk" {
  name                        = "kv-${var.project_name}-${var.environment}" # Must be globally unique
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg_network.name
  sku_name                    = "premium" # Required for CMK/HSM
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7 # Corporate standard for recovery
  enabled_for_disk_encryption = true
  tags                        = var.tags
}

data "azurerm_client_config" "current" {}

# 2. CMK Key (Mandatory for CMK Disk Encryption)
resource "azurerm_key_vault_key" "disk_cmk" {
  name         = "aks-node-key-${var.environment}"
  key_vault_id = azurerm_key_vault.kv_cmk.id
  key_type     = "RSA"
  key_size     = 3072 # Industry standard size
  key_opts     = ["decrypt", "encrypt", "wrapKey", "unwrapKey"]
}

# 3. Disk Encryption Set (DES) - The resource AKS references
resource "azurerm_disk_encryption_set" "aks_cmk_des" {
  name                = "des-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_network.name
  key_vault_key_id    = azurerm_key_vault_key.disk_cmk.id
  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

# 4. CRITICAL: Grant the DES Managed Identity access to the Key Vault
resource "azurerm_key_vault_access_policy" "des_access" {
  key_vault_id = azurerm_key_vault.kv_cmk.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_disk_encryption_set.aks_cmk_des.identity[0].principal_id

  key_permissions = [
    "Get",
    "UnwrapKey",
    "WrapKey",
  ]
}

# ----------------------------------------------------
# 3. CALL THE AKS CHILD MODULE
# ----------------------------------------------------

module "aks_cluster" {
  source = "../../modules/aks-cluster" 

  # Pass environment inputs
  location            = var.location
  project_name        = var.project_name
  environment         = var.environment
  tags                = var.tags
  node_count          = var.node_count
  vm_size             = var.vm_size
  
  # Pass Security/Dependency Outputs (Enforcing Corporate Policy)
  admin_group_object_id = var.admin_group_object_id 
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  # CMK REFERENCE (New)
  disk_encryption_set_id = azurerm_disk_encryption_set.aks_cmk_des.id 
  
  depends_on = [
    azurerm_subnet.aks_subnet,
    azurerm_private_dns_zone_virtual_network_link.dns_link,
    azurerm_key_vault_access_policy.des_access
  ]
}

# ----------------------------------------------------
# 4. KUBERNETES PROVIDER CONFIGURATION
# ----------------------------------------------------
# Configuration omitted for brevity but required for GitOps setup later.
# provider "kubernetes" { ... }