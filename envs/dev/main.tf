# platform-infra-iac/envs/dev/main.tf

# ----------------------------------------------------
# 1. TERRAFORM CONFIGURATION (Remote State & Provider)
# ----------------------------------------------------
terraform {
  # CRITICAL: Remote State Backend for collaborative work and state locking
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-storage" 
    storage_account_name = "tfstateprodaks99"   
    container_name       = "tfstate"            
    key                  = "envs/dev/aks.terraform.tfstate" # Unique path for this environment
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # We will need the Kubernetes provider to apply YAML/Helm Charts later
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Provider configuration (uses OIDC credentials from CI pipeline)
provider "azurerm" {
  features {}
}

# ----------------------------------------------------
# 2. NETWORKING & CMK DEPENDENCIES (Security Prerequisites)
# ----------------------------------------------------
# AKS requires a pre-existing VNet and Subnet for Azure CNI.

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
  
  # Delegation is mandatory for Azure CNI networking
  delegations {
    name = "delegation"
    service_delays {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# NOTE: You must also create a Key Vault and Disk Encryption Set (DES) resource 
# here before you can pass the disk_encryption_set_id to the module call.

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
  
  # Pass Security/Dependency Inputs (Enforcing Corporate Policy)
  admin_group_object_id = var.admin_group_object_id 
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  disk_encryption_set_id = "" # <--- REPLACE WITH CMK DES ID RESOURCE OUTPUT 
  
  # Ensure the subnet is provisioned before the AKS cluster tries to use it
  depends_on = [
    azurerm_subnet.aks_subnet 
  ]
}