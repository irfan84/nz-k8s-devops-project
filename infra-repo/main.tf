# infra-repo/main.tf

# Loop through the defined environments (currently only 'dev')
resource "azurerm_resource_group" "project_rg" {
  for_each = var.environments
  name     = "rg-${var.project_name}-${each.key}" # e.g., rg-aksgitops-dev
  location = var.location
  tags     = each.value.tags
}

# 1. Azure Container Registry (ACR) - To store Docker images
resource "azurerm_container_registry" "acr" {
  for_each            = var.environments
  name                = "acr${var.project_name}${each.key}" # e.g., acraksgitopsdev
  resource_group_name = azurerm_resource_group.project_rg[each.key].name
  location            = azurerm_resource_group.project_rg[each.key].location
  sku                 = "Basic" # Cost-effective for Dev/Stage
  admin_enabled       = true    # Enabled for easy CI/CD integration
}

# 1.1 Azure Log Analytics Workspace (For Centralized Logging/Monitoring)
resource "azurerm_log_analytics_workspace" "log_workspace" {
  for_each            = var.environments
  name                = "log-${var.project_name}-${each.key}" # e.g., log-aksgitops-dev
  location            = azurerm_resource_group.project_rg[each.key].location
  resource_group_name = azurerm_resource_group.project_rg[each.key].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 2. Azure Kubernetes Service (AKS) - The core compute platform
resource "azurerm_kubernetes_cluster" "aks" {
  for_each            = var.environments
  name                = "aks-${var.project_name}-${each.key}" # e.g., aks-aksgitops-dev
  location            = azurerm_resource_group.project_rg[each.key].location
  resource_group_name = azurerm_resource_group.project_rg[each.key].name
  dns_prefix          = "aks-${var.project_name}-${each.key}"

  default_node_pool {
    name       = "systempool"
    node_count = each.value.node_count
    vm_size    = each.value.vm_size
  }

  identity {
    type = "SystemAssigned"
  }
}

# 2.1 Diagnostic Settings (Connects AKS Logs to Log Analytics Workspace)
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
  for_each                   = var.environments
  name                       = "aks-diag-${each.key}"
  target_resource_id         = azurerm_kubernetes_cluster.aks[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace[each.key].id

  # Send all available audit, cluster, and security logs from AKS
  dynamic "log" {
    for_each = ["kube-audit", "kube-apiserver", "kube-controller-manager", "kube-scheduler", "cluster-autoscaler"]
    content {
      category = log.value
      enabled  = true
      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }

  # Send all metrics (CPU, Memory, Network)
  metric {
    category = "AllMetrics"
    enabled  = true
    retention_policy {
      enabled = true
      days    = 30
    }
  }
}