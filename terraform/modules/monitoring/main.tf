# terraform/modules/monitoring/main.tf
# Creates: Log Analytics Workspace (PerGB2018 SKU, 30-day retention).
# Container Insights OMS agent is wired in Phase 4.

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}
