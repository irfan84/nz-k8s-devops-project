# platform-infra-iac/envs/prod/main.tf

# ----------------------------------------------------
# 1. TERRAFORM CONFIGURATION (Remote State & Provider)
# ----------------------------------------------------
terraform {
  # CRITICAL: Remote State Backend must point to a UNIQUE KEY for the PROD environment
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-storage" 
    storage_account_name = "tfstateprodaks99"   
    container_name       = "tfstate"            
    key                  = "envs/prod/aks.terraform.tfstate" # <-- UNIQUE PROD KEY
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
# 2. NETWORKING & CMK DEPENDENCIES (Security Prerequisites)
# ----------------------------------------------------
# Note: Resource names dynamically use var.environment (e.g., rg-aksgitops-net-prod)

resource "azurerm_resource_group" "rg_network" {
  name     = "rg-${var.project_name}-net-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_network.name
  address_space       = ["10.20.0.0/16"] # Use a separate, non-overlapping CIDR for Prod
  tags                = var.tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg_network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
  
  delegations {
    name = "delegation"
    service_delays {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ----------------------------------------------------
# 3. CALL THE AKS CHILD MODULE (Identical Call to Dev)
# ----------------------------------------------------

module "aks_cluster" {
  source = "../../modules/aks-cluster" 

  # Input variables defined in variables.tf
  location            = var.location
  project_name        = var.project_name
  environment         = var.environment
  tags                = var.tags
  node_count          = var.node_count
  vm_size             = var.vm_size
  
  # Security/Dependency Inputs
  admin_group_object_id  = var.admin_group_object_id 
  vnet_subnet_id         = azurerm_subnet.aks_subnet.id
  disk_encryption_set_id = "" # <--- REPLACE WITH PROD CMK DES ID
  
  depends_on = [
    azurerm_subnet.aks_subnet 
  ]
}

# ----------------------------------------------------
# 4. KUBERNETES PROVIDER CONFIGURATION
# ----------------------------------------------------

provider "kubernetes" {
  # This block will use outputs from the AKS module to configure the Kubernetes provider.
  # The specific attributes will be provided by the AKS module's outputs.
  # Placeholder for required credentials (e.g., host, client_certificate, etc.)
  # config_raw = module.aks_cluster.kube_config_raw
}