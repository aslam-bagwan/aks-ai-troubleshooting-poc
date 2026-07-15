# terraform/bootstrap/main.tf
# Alternative to scripts/bootstrap-state.sh.
# Creates the Terraform remote state backend using Terraform itself.
# This directory intentionally uses LOCAL state — it cannot use the remote
# backend before that backend exists (chicken-and-egg).
#
# Usage (run from this directory):
#   cp terraform.tfvars.example terraform.tfvars   # fill in values
#   terraform init
#   terraform apply
#   terraform output terraform_init_command        # copy the init command
#
# RECOMMENDED: Use scripts/bootstrap-state.sh instead for a quicker one-liner.

terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # No backend block — local state is intentional for bootstrap only.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ── Variables ──────────────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for state backend resources"
  type        = string
  default     = "eastus"
}

variable "storage_account_suffix" {
  description = "4-character suffix (lowercase alphanumeric) to make storage account name globally unique. Tip: use the first 4 chars of your subscription ID with hyphens removed."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4}$", var.storage_account_suffix))
    error_message = "storage_account_suffix must be exactly 4 lowercase alphanumeric characters (a-z, 0-9)."
  }
}

# ── Locals ─────────────────────────────────────────────────────────────────

locals {
  resource_group_name  = "rg-tfstate-poc"
  storage_account_name = "stpocaksstate${var.storage_account_suffix}"
  container_name       = "tfstate"

  tags = {
    project    = "aks-ai-poc"
    managed_by = "bootstrap"
    purpose    = "terraform-state"
  }
}

# ── Resources ──────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "tfstate" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = local.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ── Outputs ────────────────────────────────────────────────────────────────

output "storage_account_name" {
  description = "Storage account name for the Terraform remote backend."
  value       = azurerm_storage_account.tfstate.name
}

output "terraform_init_command" {
  description = "Copy-paste command to initialize the dev environment Terraform backend."
  value       = "terraform init -backend-config=\"storage_account_name=${azurerm_storage_account.tfstate.name}\""
}
