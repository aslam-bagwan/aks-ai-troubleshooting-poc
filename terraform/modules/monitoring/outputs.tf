# terraform/modules/monitoring/outputs.tf

output "workspace_id" {
  description = "Resource ID of the Log Analytics Workspace. Required for Phase 4 Container Insights."
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_key" {
  description = "Primary shared key for the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}
