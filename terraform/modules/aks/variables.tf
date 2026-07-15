# terraform/modules/aks/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group where the AKS cluster will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "cluster_name" {
  description = "Name for the AKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use. null = latest stable GA (AKS default)."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Resource ID of the AKS node subnet."
  type        = string
}

variable "identity_id" {
  description = "Resource ID of the user-assigned Managed Identity for the AKS control plane."
  type        = string
}

variable "node_vm_size" {
  description = "VM size for the system node pool. Standard_B2s is burstable and cost-effective for POC."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes in the system node pool."
  type        = number
  default     = 1
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for each node."
  type        = number
  default     = 30
}

variable "pod_cidr" {
  description = "CIDR range for pods (kubenet). Must not overlap with vnet_cidr or service_cidr."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services. Must not overlap with vnet_cidr or pod_cidr."
  type        = string
  default     = "10.96.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the cluster DNS service. Must be within service_cidr."
  type        = string
  default     = "10.96.0.10"
}

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
