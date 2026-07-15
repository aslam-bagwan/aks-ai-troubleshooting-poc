# terraform/modules/aks/main.tf
# Creates: AKS cluster — kubenet networking, user-assigned MI, local K8s accounts.
# Container Insights oms_agent added in Phase 4.

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # Local K8s accounts + K8s RBAC (no Entra ID — single-person POC; see AGENT_CONTEXT.md A04)
  local_account_disabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = var.os_disk_size_gb
    vnet_subnet_id  = var.subnet_id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin = "kubenet"
    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # ── Phase 4 hook: Container Insights ────────────────────────────────────
  # Uncomment in Phase 4 and pass law_workspace_id variable:
  # oms_agent {
  #   log_analytics_workspace_id = var.law_workspace_id
  # }

  tags = var.tags
}
