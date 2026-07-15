# Runbook — AKS AI Troubleshooting POC

> This document covers manual prerequisites and step-by-step local validation. Refer to [AGENT_CONTEXT.md](../AGENT_CONTEXT.md) for project decisions and assumptions.

---

## Manual Prerequisites

The following must exist **before** running any Terraform or pipeline commands. They are out of scope for automated provisioning.

### 1. Azure Subscription

- A valid Azure subscription (e.g., Visual Studio subscription)
- Your user account must have **Contributor** (or Owner) rights on the subscription

### 2. Local Tooling

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Azure CLI (`az`) | 2.55+ | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Terraform | 1.7+ | https://developer.hashicorp.com/terraform/downloads |
| kubectl | 1.27+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.13+ | https://helm.sh/docs/intro/install/ |
| Git | 2.40+ | https://git-scm.com/downloads |

### 3. Azure DevOps (required for pipeline phases only)

| Item | Notes |
|------|-------|
| ADO Organization | Must already exist (assumption A07) |
| ADO Project | Must already exist (assumption A07) |
| Service connection `sc-azure-poc` | Azure Resource Manager, Contributor on subscription |
| ADO Environment `dev` | With manual approval gate configured |
| Variable group `vg-aks-poc-dev` | See pipeline design section in design doc |

---

## Step-by-Step: Local Setup

### Step 1 — Clone and authenticate

```bash
git clone <repo-url>
cd aks-ai-troubleshooting-poc

# Login to Azure
az login
az account set --subscription "<subscription-id>"
az account show   # verify correct subscription
```

### Step 2 — Bootstrap Terraform remote state (one-time only)

> Skip if the Storage Account for remote state already exists.

```bash
bash scripts/bootstrap-state.sh
# Note the storage account name printed at the end — you'll need it in Step 3
```

This creates:
- Resource Group: `rg-tfstate-poc`
- Storage Account: `stpocaksstate<suffix>` (name printed by script)
- Blob container: `tfstate`

### Step 3 — Configure Terraform variables

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
# Edit terraform.tfvars — fill in:
#   subscription_id = "<your-subscription-id>"
#   state_storage_account_name = "<output from Step 2>"
# The .tfvars file is gitignored — never commit it
```

### Step 4 — Initialize and plan Terraform

```bash
cd terraform/environments/dev
terraform init   # connects to remote state backend
terraform plan   # review what will be created
```

Expected resources on first plan: ~8 (resource group, VNet, subnet, NSG, managed identity, role assignment, Log Analytics workspace, AKS cluster).

### Step 5 — Apply infrastructure

```bash
terraform apply   # type 'yes' when prompted
# Takes approximately 5–10 minutes (AKS provisioning is the longest step)
```

### Step 6 — Connect to AKS

```bash
# The terraform output shows the exact command:
terraform output aks_get_credentials_cmd
# Example: az aks get-credentials --resource-group rg-aks-poc-dev --name aks-poc-dev

az aks get-credentials --resource-group rg-aks-poc-dev --name aks-poc-dev
kubectl get nodes   # should show 1 node in Ready state
```

### Step 7 — Deploy the sample application

```bash
cd <repo-root>
helm upgrade --install demo-app ./helm/demo-app \
  -f ./helm/demo-app/values-dev.yaml \
  --set app.secret="test-value"   # placeholder value, not a real secret

kubectl get pods     # demo-app pod should be Running
kubectl get services # demo-app service should be visible
```

### Step 8 — Validate application access

```bash
# Port-forward to verify nginx is serving
kubectl port-forward svc/demo-app 8080:80
# Open http://localhost:8080 in browser — should show nginx welcome page
```

---

## Teardown (cost control)

To avoid Azure costs when not actively using the cluster:

```bash
# Option A: Stop the AKS cluster (fastest, preserves config)
az aks stop --resource-group rg-aks-poc-dev --name aks-poc-dev

# Option B: Destroy all infrastructure (complete teardown)
cd terraform/environments/dev
terraform destroy   # type 'yes' when prompted
```

> The Terraform remote state backend (`rg-tfstate-poc` / Storage Account) is intentionally NOT destroyed by `terraform destroy` — it lives outside the main Terraform state. Delete it manually if needed.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `terraform init` fails — backend not found | Bootstrap script not run | Run `scripts/bootstrap-state.sh` first |
| `az aks get-credentials` fails | Cluster not yet ready | Wait for `terraform apply` to complete |
| Pod in `Pending` state | Node not ready / resource limits | Check `kubectl describe pod <name>` |
| `helm upgrade` fails — namespace not found | Namespace not created | Add `--create-namespace` flag |
| AKS node shows `NotReady` | Node pool starting up | Wait 2–3 min after cluster creation |

---

## Key Contacts / Links

> _To be filled in by the project owner — e.g., ADO project URL, subscription portal link._

---

*This runbook will be updated as each implementation phase completes.*
