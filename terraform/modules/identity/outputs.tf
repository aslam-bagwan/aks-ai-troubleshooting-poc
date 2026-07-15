# terraform/modules/identity/outputs.tf

output "identity_id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.aks.id
}

output "identity_client_id" {
  description = "Client ID of the managed identity."
  value       = azurerm_user_assigned_identity.aks.client_id
}

output "identity_principal_id" {
  description = "Principal (object) ID of the managed identity."
  value       = azurerm_user_assigned_identity.aks.principal_id
}
