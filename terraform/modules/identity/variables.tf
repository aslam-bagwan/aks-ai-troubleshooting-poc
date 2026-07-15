# terraform/modules/identity/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group where the managed identity will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "identity_name" {
  description = "Name for the user-assigned Managed Identity."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the AKS node subnet. The identity is granted Network Contributor on this subnet."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
