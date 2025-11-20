# platform-infra-iac/envs/dev/variables.tf

# ----------------------------------------------------
# 1. ROOT PROJECT CONFIGURATION (Passed to AKS Module)
# ----------------------------------------------------
variable "location" {
  description = "The Azure region for the Dev deployment."
  type        = string
  default     = "eastus" # Choose your desired region
}

variable "project_name" {
  description = "A short name for the project prefix."
  type        = string
  default     = "aksgitops"
}

variable "environment" {
  description = "The name of the environment."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags applied to all resources in this environment."
  type        = map(string)
  default = {
    Environment = "Dev"
    Project     = "AKS-GitOps"
    CostCenter  = "12345"
  }
}

# ----------------------------------------------------
# 2. AKS MODULE INPUTS (Tuning the Cluster)
# ----------------------------------------------------

variable "node_count" {
  description = "The number of nodes for the default system pool."
  type        = number
  default     = 1 # Keep low for dev environment cost saving
}

variable "vm_size" {
  description = "The VM size for the AKS nodes."
  type        = string
  default     = "Standard_B2s"
}

# ----------------------------------------------------
# 3. SECURITY INPUTS (REQUIRED FOR CORPORATE POLICIES)
# ----------------------------------------------------
# This forces the use of a specific group for cluster-admin access.
variable "admin_group_object_id" {
  description = "The Azure AD Object ID for the cluster administrator group."
  type        = string
  # IMPORTANT: REPLACE THIS PLACEHOLDER with the actual Object ID of your Entra ID group
  default     = "00000000-0000-0000-0000-000000000000" 
}