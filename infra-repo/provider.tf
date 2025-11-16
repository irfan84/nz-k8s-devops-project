# infra-repo/provider.tf

# Define the required providers and their versions
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
  # Authentication uses the ARM_CLIENT_ID, ARM_CLIENT_SECRET, etc. 
  # environment variables set by your script.
}