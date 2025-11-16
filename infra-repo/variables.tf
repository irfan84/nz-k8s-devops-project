# infra-repo/variables.tf

variable "location" {
  description = "The Azure region to deploy resources."
  type        = string
  default     = "newzealandnorth"
}

variable "project_name" {
  description = "A short name for the project, used to prefix resource names."
  type        = string
  default     = "aksgitops"
}

variable "environments" {
  description = "Map of environment names and their specific settings."
  type = map(object({
    node_count = number
    vm_size    = string
    tags       = map(string)
  }))
  # Defining the dev and stage environments for a single deployment
  default = {
    "dev" = {
      node_count = 1
      vm_size    = "Standard_B2s" # Cost-effective for Dev
      tags       = { environment = "dev", tier = "aks" }
    }
    # We will build out the 'stage' environment later to demonstrate reuse, 
    # but for the first run, focus on 'dev'.
  }
}