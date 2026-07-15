# terraform/environments/dev/main.tf
# Root module — creates shared resource group and wires all sub-modules.

locals {
  # Naming convention: {resource-abbrev}-{project}-{env}
  name_suffix = "${var.project}-${var.environment}"

  common_tags = {
    project     = "aks-ai-poc"
    environment = var.environment
    managed_by  = "terraform"
    phase       = "phase-3"
  }
}

# ── Shared Resource Group ──────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

# ── Networking ─────────────────────────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  vnet_name               = "vnet-${local.name_suffix}"
  vnet_address_space      = [var.vnet_cidr]
  subnet_name             = "snet-${local.name_suffix}"
  subnet_address_prefixes = [var.subnet_cidr]
  nsg_name                = "nsg-${local.name_suffix}"
  tags                    = local.common_tags
}

# ── Identity ───────────────────────────────────────────────────────────────

module "identity" {
  source = "../../modules/identity"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  identity_name       = "mi-${local.name_suffix}"
  subnet_id           = module.networking.subnet_id
  tags                = local.common_tags
}

# ── Monitoring (Log Analytics Workspace) ──────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = "law-${local.name_suffix}"
  retention_days      = var.law_retention_days
  tags                = local.common_tags
}

# ── AKS Cluster ────────────────────────────────────────────────────────────

module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  cluster_name        = "aks-${local.name_suffix}"
  kubernetes_version  = var.kubernetes_version
  subnet_id           = module.networking.subnet_id
  identity_id         = module.identity.identity_id
  node_vm_size        = var.node_vm_size
  node_count          = var.node_count
  pod_cidr            = var.pod_cidr
  service_cidr        = var.service_cidr
  dns_service_ip      = var.dns_service_ip
  tags                = local.common_tags

  # Ensure Network Contributor role assignment completes before AKS provisions nodes
  depends_on = [module.identity]
}
