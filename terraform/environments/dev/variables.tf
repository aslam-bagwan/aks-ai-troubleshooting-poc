# terraform/environments/dev/variables.tf
# All input variable declarations for the dev environment.
# Defaults are set for low-cost POC values.
# Sensitive values (subscription_id) must be provided via terraform.tfvars (gitignored).

# ── Identity / Scope ───────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure subscription ID. Provided via terraform.tfvars — never hardcoded or committed."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment label used in resource names and tags (e.g. dev, staging)."
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project label used in resource names and tags."
  type        = string
  default     = "poc"
}

# ── Networking ─────────────────────────────────────────────────────────────

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the AKS node subnet."
  type        = string
  default     = "10.0.1.0/24"
}

# ── AKS ────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes version. null = latest stable GA (recommended for POC to avoid manual pin management)."
  type        = string
  default     = null
}

variable "node_vm_size" {
  description = "VM size for the AKS system node pool. Standard_B2s (2 vCPU / 4 GB) is the cost-optimised default."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes in the system node pool. 1 node for POC cost control."
  type        = number
  default     = 1
}

variable "pod_cidr" {
  description = "CIDR range allocated to pods (kubenet). Must not overlap with vnet_cidr or service_cidr."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services. Must not overlap with vnet_cidr or pod_cidr."
  type        = string
  default     = "10.96.0.0/16"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must be within service_cidr and not the first address."
  type        = string
  default     = "10.96.0.10"
}

# ── Monitoring ─────────────────────────────────────────────────────────────

variable "law_retention_days" {
  description = "Log Analytics Workspace data retention in days. 30 is the minimum and default."
  type        = number
  default     = 30

  validation {
    condition     = var.law_retention_days >= 30
    error_message = "Log Analytics retention must be at least 30 days."
  }
}
