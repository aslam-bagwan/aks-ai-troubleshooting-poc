# terraform/environments/dev/main.tf
# Root module — wires together all sub-modules.
# Module calls are added in Phase 3 once module implementations are complete.
# This file intentionally contains only locals for Phase 2.

locals {
  # Naming convention: {resource-abbrev}-{project}-{env}
  name_suffix = "${var.project}-${var.environment}"

  # Applied to all resources for cost tracking and lifecycle management
  common_tags = {
    project     = "aks-ai-poc"
    environment = var.environment
    managed_by  = "terraform"
    phase       = "phase-2"   # Update each phase
  }
}

# ── Module calls (Phase 3) ─────────────────────────────────────────────────
# Uncommented and implemented in Phase 3:
#
# module "networking" {
#   source = "../../modules/networking"
#   ...
# }
#
# module "identity" {
#   source = "../../modules/identity"
#   ...
# }
#
# module "monitoring" {
#   source = "../../modules/monitoring"
#   ...
# }
#
# module "aks" {
#   source = "../../modules/aks"
#   ...
# }
