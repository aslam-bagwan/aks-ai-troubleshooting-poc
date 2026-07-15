# terraform/modules/networking/outputs.tf

output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "Resource ID of the AKS node subnet."
  value       = azurerm_subnet.aks.id
}

output "nsg_id" {
  description = "Resource ID of the Network Security Group."
  value       = azurerm_network_security_group.main.id
}
