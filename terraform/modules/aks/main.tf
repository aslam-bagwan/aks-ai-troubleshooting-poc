# terraform/modules/aks/main.tf
# Module implementation added in Phase 3.
# Creates: AKS cluster with kubenet networking, user-assigned managed identity,
#          local Kubernetes accounts (no Entra ID), 1x Standard_B2s system node pool.
# Container Insights oms_agent block added in Phase 4.
