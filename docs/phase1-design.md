# Phase 1 — Solution Design

> Status: **Awaiting approval** — no implementation files created yet.
> All assumptions and decisions are logged in `/AGENT_CONTEXT.md`.

---

## 1. Repository Structure

```
/
├── AGENT_CONTEXT.md                  # Project context, decisions, assumptions (git-tracked)
├── .gitignore                        # Excludes: *.tfvars, .terraform/, kubeconfig, etc.
│
├── terraform/
│   ├── bootstrap/                    # One-time backend bootstrap (run once manually)
│   │   └── main.tf                   # Creates storage account + blob container for remote state
│   │
│   ├── modules/
│   │   ├── networking/               # VNet, subnets, NSG
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── identity/                 # User-assigned Managed Identity + RBAC assignments
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── monitoring/               # Log Analytics Workspace
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── aks/                      # AKS cluster + node pool
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── environments/
│       └── dev/                      # Dev environment root configuration
│           ├── main.tf               # Module calls, wiring
│           ├── variables.tf          # All input variable declarations
│           ├── outputs.tf            # Re-exported module outputs
│           ├── providers.tf          # AzureRM + Kubernetes provider config
│           ├── backend.tf            # Remote state backend config
│           └── terraform.tfvars.example  # Non-secret example values (committed)
│
├── helm/
│   └── demo-app/                     # Reusable sample app chart
│       ├── Chart.yaml
│       ├── values.yaml               # Default values
│       ├── values-dev.yaml           # Dev environment overrides
│       └── templates/
│           ├── _helpers.tpl          # Common label/name helpers
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── configmap.yaml
│           ├── secret.yaml           # Placeholder — TODO: replace with Key Vault CSI driver
│           └── ingress.yaml          # Disabled by default (ingress.enabled: false)
│
├── pipelines/
│   ├── terraform-plan.yml            # PR validation: init + plan only
│   ├── terraform-apply.yml           # Main branch: plan + apply with approval gate
│   ├── helm-deploy.yml               # Helm chart deployment to AKS
│   ├── validation.yml                # Post-deploy rollout and readiness checks
│   └── templates/
│       ├── terraform-steps.yml       # Reusable Terraform step template
│       └── helm-steps.yml            # Reusable Helm step template
│
├── scripts/
│   └── bootstrap-state.sh            # One-time: creates Azure Storage Account for Terraform state
│
└── docs/
    ├── phase1-design.md              # This document
    └── runbook.md                    # Step-by-step local setup and validation guide
```

**Folder purposes:**

| Folder | Purpose |
|--------|---------|
| `terraform/bootstrap/` | Solves the chicken-and-egg problem: creates the Storage Account used as Terraform remote backend, run manually once before any other Terraform command |
| `terraform/modules/` | Reusable, composable infrastructure building blocks — each module owns one concern |
| `terraform/environments/dev/` | Environment-specific root config; calls modules, passes variables, declares backend |
| `helm/demo-app/` | A generic, values-driven chart deployable to any environment via values overrides |
| `pipelines/` | One file per pipeline concern; `templates/` contains step-level reusable snippets |
| `scripts/` | Shell helpers for one-off operations not suited to Terraform or pipelines |
| `docs/` | Human-readable runbooks and design documents |

---

## 2. Azure Infrastructure Architecture

### Mandatory components

| Component | Resource Type | Name Convention | Notes |
|-----------|-------------|----------------|-------|
| Resource Group | `azurerm_resource_group` | `rg-aks-poc-dev` | All resources grouped here |
| Virtual Network | `azurerm_virtual_network` | `vnet-aks-poc-dev` | CIDR: `10.0.0.0/16` |
| AKS Subnet | `azurerm_subnet` | `snet-aks-poc-dev` | CIDR: `10.0.1.0/24` |
| NSG | `azurerm_network_security_group` | `nsg-aks-poc-dev` | Attached to AKS subnet |
| User-assigned MI | `azurerm_user_assigned_identity` | `mi-aks-poc-dev` | Used by AKS control plane |
| RBAC assignment | `azurerm_role_assignment` | — | MI → Network Contributor on subnet |
| Log Analytics WS | `azurerm_log_analytics_workspace` | `law-aks-poc-dev` | PerGB2018 SKU, 30-day retention |
| AKS Cluster | `azurerm_kubernetes_cluster` | `aks-poc-dev` | kubenet, local accounts, 1 system node |

### Optional / future components

| Component | Phase |
|-----------|-------|
| Container Insights addon (`oms_agent`) | Phase 4 |
| Azure Key Vault | Phase 4 |
| Azure Container Registry | Future |
| Application Gateway (Ingress) | Future |
| Additional user node pools | Future |

### Networking design

```
VNet: 10.0.0.0/16
└── Subnet: snet-aks-poc-dev  10.0.1.0/24   ← AKS nodes
    └── NSG: nsg-aks-poc-dev (default deny-all inbound, allow AKS control plane)

AKS kubenet config:
  pod_cidr:         10.244.0.0/16
  service_cidr:     10.0.100.0/16
  dns_service_ip:   10.0.100.10
```

### RBAC assignments

| Principal | Role | Scope | Reason |
|-----------|------|-------|--------|
| `mi-aks-poc-dev` | Network Contributor | `snet-aks-poc-dev` | AKS requires MI permission to configure subnet routes (kubenet) |

### Outputs

| Output | Description |
|--------|------------|
| `aks_cluster_name` | Cluster name for `az aks get-credentials` |
| `aks_resource_group` | Resource group name |
| `aks_get_credentials_cmd` | Pre-formatted `az aks get-credentials ...` command |
| `law_workspace_id` | Log Analytics workspace resource ID (needed for Phase 4) |
| `vnet_id` | VNet resource ID |
| `subnet_id` | AKS subnet resource ID |

---

## 3. Terraform Architecture

### State backend — chicken-and-egg solution

```
Step 1 (one-time, manual):
  Run scripts/bootstrap-state.sh
  → Creates: Resource Group rg-tfstate-poc
             Storage Account stpocaksstate<4-char-suffix>
             Blob container: tfstate
  → Outputs: storage account name (not sensitive)

Step 2 (CI/CD and local):
  terraform init -backend-config="storage_account_name=<output>"
  → All subsequent terraform commands use remote state
```

The bootstrap Storage Account is intentionally small (LRS, Standard, no versioning overhead). Its Terraform is minimal and self-contained in `terraform/bootstrap/main.tf` — it does NOT use remote state itself (it uses local state for its own small footprint).

### Module structure

```
modules/
├── networking/    vars: rg_name, location, vnet_cidr, subnet_cidr, tags
│                  out:  vnet_id, subnet_id
│
├── identity/      vars: rg_name, location, name, subnet_id, tags
│                  out:  identity_id, identity_client_id, identity_principal_id
│
├── monitoring/    vars: rg_name, location, name, retention_days, tags
│                  out:  workspace_id, workspace_key (sensitive)
│
└── aks/           vars: rg_name, location, cluster_name, subnet_id,
│                        identity_id, kubernetes_version, node_vm_size,
│                        node_count, pod_cidr, service_cidr, dns_ip, tags
│                  out:  cluster_id, cluster_name, kube_config (sensitive)
```

### Provider configuration

```hcl
# providers.tf
terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

### Environment strategy

Single `dev` environment for Phase 1. Directory structure allows adding `staging/`, `prod/` under `environments/` later without any module changes.

### Naming convention

`{resource-abbrev}-{project}-{env}` — e.g., `aks-poc-dev`, `vnet-poc-dev`, `rg-poc-dev`

### Tagging strategy

```hcl
tags = {
  project     = "aks-ai-poc"
  environment = var.environment       # "dev"
  managed_by  = "terraform"
  phase       = "phase-1"             # updated each phase
}
```

### Variable management

| File | Contents | Committed? |
|------|---------|-----------|
| `variables.tf` | Variable declarations with type + description | Yes |
| `terraform.tfvars.example` | All variables with non-sensitive placeholder values | Yes |
| `terraform.tfvars` | Real values incl. `subscription_id = "<sub-id>"` | **No** (gitignored) |

### Output strategy

Each module exports minimal identifiers. Root `outputs.tf` re-exports all relevant values. Sensitive outputs (workspace key, kube_config) marked `sensitive = true`.

---

## 4. AKS Design

### Summary

| Parameter | Value | Notes |
|-----------|-------|-------|
| Kubernetes version | Latest stable GA | No hard pin — use `null` to track latest GA, or pin to a specific version at deploy time |
| Node VM size | `Standard_B2s` | 2 vCPU / 4 GB RAM / burstable — ~$34/month |
| Node count | 1 | Fixed; no autoscaler |
| OS disk | 30 GB managed (Standard_LRS) | Sufficient for system components |
| Networking | kubenet | Simpler, no extra VNet CIDR constraints |
| Auth model | Local K8s accounts + K8s RBAC | No Entra ID — appropriate for single-person POC |
| Identity | User-assigned Managed Identity | No client secret rotation |
| Monitoring addon | Disabled (Phase 4) | Log Analytics WS created, addon added later |
| Auto-scaling | Disabled | Cost control |
| Budget ceiling | **~$50/month** while cluster is running | Stop cluster when idle to save compute costs |

### Trade-offs documented

| Choice | Trade-off |
|--------|----------|
| kubenet over Azure CNI | Slightly higher latency (extra hop via kube-proxy), simpler VNet design. Adequate for POC. |
| Local accounts over Entra ID | Weaker identity governance. Acceptable for single-person POC — revisit before multi-user use. |
| No autoscaler | Must manually scale if load increases. Acceptable for POC to control costs. |
| B2s burstable | CPU throttled when burst credit exhausted. Fine for intermittent POC workloads. |
| Container Insights deferred | No pod/container metrics in Phase 1. Log Analytics workspace ready — adding addon in Phase 4 is a 2-line Terraform change. |

---

## 5. Helm Application Design

### Chart: `demo-app`

```
helm/demo-app/
├── Chart.yaml           # name: demo-app, version: 0.1.0, appVersion: "latest"
├── values.yaml          # All defaults (image, replicas, resources, etc.)
├── values-dev.yaml      # Dev overrides (lower resource limits)
└── templates/
    ├── _helpers.tpl     # {{ include "demo-app.fullname" . }}, common labels
    ├── deployment.yaml  # Deployment with liveness/readiness probes, resource limits
    ├── service.yaml     # ClusterIP service (NodePort toggleable via values)
    ├── configmap.yaml   # App config as environment variables
    ├── secret.yaml      # K8s Secret placeholder
    └── ingress.yaml     # Ingress (disabled by default)
```

### `values.yaml` structure

```yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:   { cpu: "250m", memory: "128Mi" }
  requests: { cpu: "100m", memory: "64Mi"  }

ingress:
  enabled: false

app:
  config:
    LOG_LEVEL: "info"
  # Interim secrets story: value below is a placeholder only.
  # Pass real value via: helm upgrade --install ... --set app.secret=<value>
  # TODO: replace with Key Vault CSI driver in Phase 4.
  secret: "REPLACE_ME"
```

### Interim secrets story (explicit)

- `secret.yaml` creates a K8s `Secret` with key `app-secret` sourced from `.Values.app.secret`
- Default value in `values.yaml` is the string `"REPLACE_ME"` — never a real secret
- For local/CI testing: operator passes `--set app.secret=<real-value>` at deploy time, which is NOT committed
- This is intentionally temporary. Phase 4 will replace this with the Azure Key Vault CSI driver (`secrets-store-csi-driver`) and an `SecretProviderClass`, removing the need to pass secrets via Helm values entirely
- A `# TODO: Key Vault CSI driver — Phase 4` comment is added to the template to make the gap explicit

### Sample application

`nginx:1.27` — serves a default HTML page, no application secrets required. Ideal for validating the full deployment path (Deployment → Service → Ingress) without any application dependencies.

---

## 6. CI/CD Architecture

### Pipeline files

```
pipelines/
├── terraform-plan.yml       # Trigger: PR to main — runs plan only, no apply
├── terraform-apply.yml      # Trigger: merge to main — plan + approval gate + apply
├── helm-deploy.yml          # Trigger: after infra apply — deploys Helm chart
├── validation.yml           # Trigger: after helm deploy — verifies pod readiness
└── templates/
    ├── terraform-steps.yml  # Reusable: az login, terraform init/plan/apply steps
    └── helm-steps.yml       # Reusable: az aks get-credentials, helm upgrade steps
```

### Stage flow

```
PR opened
  └── terraform-plan.yml (auto)
        Stage: Plan
          - az login (service connection)
          - terraform init (remote backend)
          - terraform plan → artifact: terraform.tfplan

PR merged to main
  └── terraform-apply.yml (auto trigger)
        Stage: Plan    — re-runs plan
        Stage: Approve — manual gate (ADO environment approval)
        Stage: Apply   — terraform apply terraform.tfplan
        Stage: Export  — parse outputs, write to pipeline variables

  └── helm-deploy.yml (auto, depends on apply)
        Stage: Deploy
          - az aks get-credentials
          - helm upgrade --install demo-app ./helm/demo-app -f values-dev.yaml

  └── validation.yml (auto, depends on deploy)
        Stage: Validate
          - kubectl rollout status deployment/demo-app
          - kubectl get pods -l app=demo-app
```

### ADO prerequisites (assumption A07)

> **Assumed to already exist — not in scope to create:**
> - ADO organization
> - ADO project
> - Azure service connection named `sc-azure-poc` (Contributor on subscription)
> - ADO environment named `dev` (with manual approval gate configured)
>
> These are documented in `docs/runbook.md` as manual prerequisites.

### Variable groups and secrets

| Variable Group | Contains | How stored |
|---------------|---------|-----------|
| `vg-aks-poc-dev` | `RESOURCE_GROUP`, `AKS_CLUSTER_NAME`, `LOCATION` | ADO variable group, not secret |
| Pipeline-level secrets | `SUBSCRIPTION_ID`, `TENANT_ID` | ADO secret variables (not in YAML) |

**No secrets in any YAML file.** Service connection handles Azure auth. `kubeconfig` fetched dynamically via `az aks get-credentials --overwrite-existing` within the pipeline.

### Rollback strategy

| Layer | Rollback Method |
|-------|----------------|
| Helm | `helm rollback demo-app [revision]` — instant, revision-tracked |
| Terraform | Revert commit + re-run `terraform-apply` pipeline — declarative, state-backed |
| AKS | Node pool issues: `terraform apply` re-converges to declared state |

---

## 7. Implementation Roadmap

### Phase 1 — Repository scaffolding
- **Objective:** Create full folder structure, `.gitignore`, stub `README`, initial commit
- **Files created:** All empty module/template folders, `.gitignore`, `AGENT_CONTEXT.md` (already done), `docs/runbook.md` stub
- **Dependencies:** Git repo initialized ✓
- **Validation:** `git log --oneline` shows initial commit; all folders visible; `.gitignore` excludes `*.tfvars`
- **Expected outcome:** Clean, well-organized repo skeleton ready for Terraform work

### Phase 2 — Terraform foundation
- **Objective:** Bootstrap script + provider/backend config + module shells with variables and outputs
- **Files created:** `scripts/bootstrap-state.sh`, `terraform/bootstrap/main.tf`, `terraform/environments/dev/providers.tf`, `backend.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, module `variables.tf` / `outputs.tf` stubs
- **Dependencies:** Phase 1 complete
- **Validation:** `bash scripts/bootstrap-state.sh` succeeds; `terraform init` completes with remote backend; `terraform validate` passes
- **Expected outcome:** Terraform initialized against remote state; no resources deployed yet

### Phase 3 — Azure networking and AKS deployment
- **Objective:** Implement all Terraform modules; deploy full Azure infrastructure
- **Files created:** All module `main.tf` files; `terraform/environments/dev/main.tf`
- **Dependencies:** Phase 2 complete; Azure subscription credentials configured locally
- **Validation:** `terraform plan` shows expected resource count; `terraform apply` completes without errors; `az aks get-credentials` succeeds; `kubectl get nodes` shows 1 node in `Ready` state
- **Expected outcome:** Running AKS cluster; all Azure resources provisioned

### Phase 4 — Monitoring integration
- **Objective:** Enable Container Insights addon on AKS; verify metrics flowing to Log Analytics
- **Files modified:** `terraform/modules/aks/main.tf` (add `oms_agent` block); `terraform/modules/monitoring/main.tf`
- **Dependencies:** Phase 3 complete
- **Validation:** Azure Portal shows Container Insights data for the cluster; `kubectl get pods -n kube-system | grep omsagent` shows Running
- **Expected outcome:** Basic observability enabled; foundation for future AI troubleshooting agents

### Phase 5 — Helm application deployment
- **Objective:** Build full `demo-app` Helm chart; deploy to AKS
- **Files created:** Complete `helm/demo-app/` chart (all templates, `values.yaml`, `values-dev.yaml`)
- **Dependencies:** Phase 3 complete (AKS running)
- **Validation:** `helm install demo-app ./helm/demo-app -f values-dev.yaml` succeeds; `kubectl get pods` shows Running; `kubectl port-forward` accessible on localhost
- **Expected outcome:** `nginx` app running on AKS, accessible via port-forward or NodePort

### Phase 6 — Azure DevOps YAML pipelines
- **Objective:** Implement all pipeline YAML files; verify end-to-end ADO run
- **Files created:** All files in `pipelines/` and `pipelines/templates/`
- **Dependencies:** Phase 5 complete; ADO org/project/service-connection exist (A07)
- **Validation:** All four pipelines run successfully in ADO; plan/apply/deploy/validate stages pass; rollback tested manually
- **Expected outcome:** Fully automated, repeatable CI/CD pipeline from code commit to running application

### Phase 7 — End-to-end validation and documentation
- **Objective:** Full walkthrough from clone to running app; update all docs and AGENT_CONTEXT.md
- **Files modified:** `docs/runbook.md` (complete), `AGENT_CONTEXT.md` (phase log updated)
- **Dependencies:** All phases complete
- **Validation:** Follow every step in `Implementation Success Criteria` (items 1–10) from the original prompt; all pass
- **Expected outcome:** Platform foundation complete, documented, and ready for future AI troubleshooting phases

---

## Decisions to Resolve Early — Summary

All seven decisions from the requirements have been addressed:

| Decision | Resolution | See |
|----------|-----------|-----|
| Azure region | `eastus` | Assumptions A02, Key Decisions table |
| Terraform state backend | Remote (Azure Storage), bootstrap script | Assumption A03, Section 3 |
| AKS auth model | Local K8s accounts + K8s RBAC | Assumption A04, Section 4 |
| Node pool budget ceiling | `Standard_B2s` × 1, ~$50/month | Assumption A05, Section 4 |
| Interim secrets story | Helm values placeholder, `--set` at deploy time | Assumption A06, Section 5 |
| ADO prerequisites | Org/project/service-connection assumed to exist | Assumption A07, Section 6 |
| Observability hooks | Log Analytics WS now; Container Insights in Phase 4 | Assumption A08, Section 4 |

---

**STOP — Awaiting approval before any implementation files are created.**
