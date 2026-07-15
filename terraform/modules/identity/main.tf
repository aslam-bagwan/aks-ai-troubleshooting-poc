# terraform/modules/identity/main.tf
# Creates: User-assigned Managed Identity, Network Contributor role assignment on AKS subnet.
# AKS control plane uses this identity to manage subnet routes (required for kubenet).

resource "azurerm_user_assigned_identity" "aks" {
  name                = var.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                            = var.subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  skip_service_principal_aad_check = true # Managed identities skip AAD propagation delay
}
