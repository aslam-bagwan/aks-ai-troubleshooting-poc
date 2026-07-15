# terraform/modules/monitoring/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group where the Log Analytics Workspace will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "workspace_name" {
  description = "Name for the Log Analytics Workspace."
  type        = string
}

variable "retention_days" {
  description = "Data retention period in days. Minimum is 30 (free tier threshold)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 30
    error_message = "Retention days must be at least 30."
  }
}

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
