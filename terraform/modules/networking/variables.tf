# terraform/modules/networking/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group where networking resources will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_name" {
  description = "Name for the Virtual Network."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network as a list of CIDR strings."
  type        = list(string)
}

variable "subnet_name" {
  description = "Name for the AKS node subnet."
  type        = string
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the AKS node subnet as a list of CIDR strings."
  type        = list(string)
}

variable "nsg_name" {
  description = "Name for the Network Security Group attached to the AKS subnet."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
