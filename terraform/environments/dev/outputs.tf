# terraform/environments/dev/outputs.tf
# Root outputs re-exported from module outputs.

output "aks_cluster_name" {
  description = "AKS cluster name — copy into: az aks get-credentials --name <value> ..."
  value       = module.aks.cluster_name
}

output "aks_resource_group" {
  description = "Resource group name containing all POC resources."
  value       = azurerm_resource_group.main.name
}

output "aks_get_credentials_cmd" {
  description = "Pre-formatted az aks get-credentials command — run this after terraform apply."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name}"
}

output "law_workspace_id" {
  description = "Log Analytics Workspace resource ID — needed for Phase 4 Container Insights."
  value       = module.monitoring.workspace_id
}

output "vnet_id" {
  description = "Virtual Network resource ID."
  value       = module.networking.vnet_id
}

output "subnet_id" {
  description = "AKS node subnet resource ID."
  value       = module.networking.subnet_id
}
