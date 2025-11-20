# platform-infra-iac/envs/prod/variables.tf

# ----------------------------------------------------
# 1. ROOT PROJECT CONFIGURATION (Passed to AKS Module)
# ----------------------------------------------------
variable "location" {
  description = "The Azure region for the Prod deployment."
  type        = string
  default     = "eastus" # Keep consistent or choose a primary region
}

variable "project_name" {
  description = "A short name for the project prefix."
  type        = string
  default     = "aksgitops"
}

variable "environment" {
  description = "The name of the environment."
  type        = string
  default     = "prod" # <-- PRODUCTION ENVIRONMENT NAME
}

variable "tags" {
  description = "Tags applied to all resources in this environment."
  type        = map(string)
  default = {
    Environment = "Prod" # <-- PRODUCTION TAG
    Project     = "AKS-GitOps"
    CostCenter  = "12345"
    SLA         = "P1"  # <-- ADD PRODUCTION-LEVEL TAGS
  }
}

# ----------------------------------------------------
# 2. AKS MODULE INPUTS (Tuning the Cluster for Production)
# ----------------------------------------------------

variable "node_count" {
  description = "The number of nodes for the default system pool."
  type        = number
  default     = 3 # <-- HIGHER NODE COUNT FOR HIGH-AVAILABILITY (HA)
}

variable "vm_size" {
  description = "The VM size for the AKS nodes."
  type        = string
  default     = "Standard_D4s_v5" # <-- HIGHER PERFORMANCE VM SIZE
}

# ----------------------------------------------------
# 3. SECURITY INPUTS (REQUIRED FOR CORPORATE POLICIES)
# ----------------------------------------------------

variable "admin_group_object_id" {
  description = "The Azure AD Object ID for the cluster administrator group."
  type        = string
  # CRITICAL: This MUST be the Object ID of the Production Admin Group
  default     = "11111111-1111-1111-1111-111111111111" 
}