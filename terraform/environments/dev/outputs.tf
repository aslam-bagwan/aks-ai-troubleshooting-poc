# terraform/environments/dev/outputs.tf
# Root outputs re-exported from module outputs.
# Populated in Phase 3 when module calls are wired.
#
# Planned outputs (uncommented in Phase 3):
#
# output "aks_cluster_name" {
#   description = "AKS cluster name — use with: az aks get-credentials --name <value> ..."
#   value       = module.aks.cluster_name
# }
#
# output "aks_resource_group" {
#   description = "Resource group name containing the AKS cluster"
#   value       = module.aks.resource_group_name
# }
#
# output "aks_get_credentials_cmd" {
#   description = "Pre-formatted az aks get-credentials command"
#   value       = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name}"
# }
#
# output "law_workspace_id" {
#   description = "Log Analytics Workspace resource ID (needed for Phase 4 Container Insights)"
#   value       = module.monitoring.workspace_id
# }
#
# output "vnet_id" {
#   description = "Virtual Network resource ID"
#   value       = module.networking.vnet_id
# }
#
# output "subnet_id" {
#   description = "AKS subnet resource ID"
#   value       = module.networking.subnet_id
# }
