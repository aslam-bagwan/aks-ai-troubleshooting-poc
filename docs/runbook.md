# Runbook — AKS AI Troubleshooting POC

> **Single source of truth for operations.** Read [AGENT_CONTEXT.md](../AGENT_CONTEXT.md) first for all decisions, assumptions, and phase history.

---

## 0. Quick Reference

| What | Value |
|------|-------|
| Resource Group | `rg-poc-dev` |
| AKS Cluster | `aks-poc-dev` |
| Log Analytics WS | `law-poc-dev` |
| VNet | `vnet-poc-dev` |
| TF State RG | `rg-tfstate-poc` |
| Region | `eastus` |
| Helm release | `demo-app` (namespace: `default`) |
| ADO service connection | `sc-azure-poc` |
| ADO variable group | `vg-aks-poc-dev` |
| ADO environment | `dev` |

---

## 1. Manual Prerequisites

The following must exist **before** running any Terraform or pipeline commands.

### Azure Subscription
- Valid Azure subscription (e.g., Visual Studio subscription)
- Your account must have **Contributor** (or Owner) rights

### Local Tooling

| Tool | Min Version | Install |
|------|------------|---------|
| Azure CLI (`az`) | 2.55+ | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Terraform | 1.7+ | https://developer.hashicorp.com/terraform/downloads |
| kubectl | 1.27+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.13+ | https://helm.sh/docs/intro/install/ |
| Git | 2.40+ | https://git-scm.com/downloads |
| Bash (bootstrap only) | any | WSL / Git Bash / macOS / Azure Cloud Shell |

### Azure DevOps (pipelines only — see Section 5)

| Item | Notes |
|------|-------|
| ADO Organization | Must exist — creation out of scope (A07) |
| ADO Project | Must exist — creation out of scope (A07) |
| Service connection `sc-azure-poc` | Azure Resource Manager, Contributor on subscription |
| ADO Environment `dev` | Created in ADO with Pre-deployment Approval check configured |
| Variable group `vg-aks-poc-dev` | See Section 5 for required variables |
| Secret pipeline variable `APP_SECRET` | Defined on `helm-deploy` pipeline only — never in YAML |

---

## 2. Implementation Success Criteria Walkthrough

### Step 1 — Clone the repository

```bash
git clone <repo-url>
cd aks-ai-troubleshooting-poc
```

### Step 2 — Read AGENT_CONTEXT.md

```bash
cat AGENT_CONTEXT.md     # or open in editor
```

This file contains all key decisions, assumptions, and the full phase log. No re-explaining needed across sessions.

### Step 3 — Configure Azure subscription

```bash
az login
az account list --output table          # list available subscriptions
az account set --subscription "<name-or-id>"
az account show                         # verify the correct subscription is active
```

Copy the subscription ID shown — you'll need it for `terraform.tfvars`.

### Step 4 — Bootstrap Terraform remote state (one-time only)

> Skip if `rg-tfstate-poc` and the storage account already exist.

```bash
bash scripts/bootstrap-state.sh
# Prints: storage account name and the exact terraform init command
```

This creates:
- Resource Group: `rg-tfstate-poc`
- Storage Account: `stpocaksstate<suffix>` (suffix derived from subscription ID)
- Blob container: `tfstate`

**On Windows:** run from Git Bash, WSL, or Azure Cloud Shell.

### Step 5 — Configure Terraform variables

```bash
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars

# Edit terraform.tfvars — fill in:
#   subscription_id = "<your-subscription-id>"
# All other variables have acceptable defaults.
```

> `terraform.tfvars` is gitignored — **never commit it**.

### Step 6 — Run Terraform initialization

```bash
cd terraform/environments/dev

terraform init \
  -backend-config="storage_account_name=<name-from-step-4>"
# Expected: "Terraform has been successfully initialized!"
```

### Step 7 — Run Terraform plan

```bash
terraform plan
# Expected: Plan shows ~9 resources to create, 0 to destroy
# Review all resources before applying
```

Expected resources: resource group, VNet, subnet, NSG, managed identity, role assignment, Log Analytics workspace, AKS cluster.

### Step 8 — Deploy Azure infrastructure

```bash
terraform apply
# Type 'yes' when prompted
# Takes approximately 8–12 minutes (AKS provisioning is the longest step)
```

After completion, note the outputs:
```bash
terraform output                        # shows all outputs
terraform output aks_get_credentials_cmd   # copy this command
```

### Step 9 — Connect to AKS

```bash
# Run the command from step 8's output, e.g.:
az aks get-credentials \
  --resource-group rg-poc-dev \
  --name aks-poc-dev

# Verify connection:
kubectl get nodes
# Expected: NAME   STATUS   Ready   ...
```

### Step 10a — Validate Helm chart (optional but recommended)

```bash
cd <repo-root>

# Lint the chart
helm lint ./helm/demo-app

# Render templates locally (no cluster needed)
helm template demo-app ./helm/demo-app \
  -f helm/demo-app/values-dev.yaml \
  --set app.secret=test-value
# Expected: YAML output, no errors
```

### Step 10b — Deploy application using Helm

```bash
helm upgrade --install demo-app ./helm/demo-app \
  -f helm/demo-app/values-dev.yaml \
  --set app.secret=test-placeholder \
  --create-namespace \
  --namespace default \
  --wait

# Verify:
kubectl get pods --namespace default
# Expected: demo-app-xxxxx   1/1   Running
```

### Step 11 — Verify application availability

```bash
# Check service
kubectl get service demo-app --namespace default

# Port-forward to access locally
kubectl port-forward svc/demo-app 8080:80 --namespace default &
curl http://localhost:8080
# Expected: nginx welcome page HTML
# kill %1   (to stop port-forward)
```

---

## 3. Azure DevOps Pipeline Setup

### 3a. Import pipelines into ADO

In your ADO project, create 4 new pipeline definitions, each pointing to:

| Pipeline | YAML file |
|---------|-----------|
| `terraform-plan` | `pipelines/terraform-plan.yml` |
| `terraform-apply` | `pipelines/terraform-apply.yml` |
| `helm-deploy` | `pipelines/helm-deploy.yml` |
| `validation` | `pipelines/validation.yml` |

### 3b. Create variable group `vg-aks-poc-dev`

In ADO (Pipelines → Library → Variable groups), create a group named `vg-aks-poc-dev` with:

| Variable | Value | Secret? |
|---------|-------|---------|
| `TF_STATE_STORAGE_ACCOUNT` | `stpocaksstate<suffix>` (from bootstrap) | No |
| `RESOURCE_GROUP` | `rg-poc-dev` | No |
| `AKS_CLUSTER_NAME` | `aks-poc-dev` | No |
| `LOCATION` | `eastus` | No |

Link this variable group to all 4 pipelines.

### 3c. Create service connection `sc-azure-poc`

In ADO (Project Settings → Service connections):
1. New service connection → Azure Resource Manager
2. Select your subscription
3. Grant Contributor role
4. Name: `sc-azure-poc`
5. Check "Grant access permission to all pipelines"

### 3d. Create environment `dev` with approval gate

In ADO (Pipelines → Environments):
1. New environment → name: `dev`
2. Open environment → Approvals and checks → Add → Approvals
3. Add your user as approver
4. Set timeout as desired (e.g., 1 hour)

### 3e. Add `APP_SECRET` as secret variable on `helm-deploy`

On the `helm-deploy` pipeline:
1. Edit → Variables → New variable
2. Name: `APP_SECRET`, Value: `<placeholder-value>`, check "Keep this value secret"
3. This is intentionally a placeholder — Key Vault CSI driver is a future phase (A06)

### 3f. Run pipelines end-to-end

**For infrastructure changes:**
1. Create a PR touching `terraform/**` → `terraform-plan.yml` runs automatically
2. Merge to `main` → `terraform-apply.yml` runs:
   - Stage 1: Plan (auto)
   - Stage 2: Approve (manual gate — approve in ADO)
   - Stage 3: Apply (auto after approval)
   - Stage 4: Export outputs (auto)

**For application deployment:**
1. Manually trigger `helm-deploy.yml`
2. Manually trigger `validation.yml` to verify

---

## 4. Rollback Procedures

| Layer | Rollback Method |
|-------|----------------|
| Helm | `helm rollback demo-app [revision]` — instant |
| Terraform | Revert commit + re-run `terraform-apply` pipeline |
| AKS cluster | `terraform apply` re-converges to declared state |

```bash
# Helm rollback example
helm history demo-app --namespace default   # list revisions
helm rollback demo-app 1 --namespace default  # roll back to revision 1
```

---

## 5. Cost Control and Teardown

### Stop cluster when not in use (fastest, preserves everything)

```bash
az aks stop --resource-group rg-poc-dev --name aks-poc-dev
# Estimated: saves ~$34/month while stopped

# Restart when needed
az aks start --resource-group rg-poc-dev --name aks-poc-dev
```

### Full infrastructure teardown

```bash
cd terraform/environments/dev
terraform destroy   # type 'yes' — destroys all resources in rg-poc-dev
```

> The bootstrap storage account (`rg-tfstate-poc`) is **not** managed by this Terraform state. Delete it manually if needed:
> ```bash
> az group delete --name rg-tfstate-poc --yes
> ```

---

## 6. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `terraform init` fails — backend not found | Bootstrap script not run | Run `scripts/bootstrap-state.sh` first |
| `terraform apply` fails — quota exceeded | vCPU quota too low | Request B2s quota increase in Azure Portal |
| `az aks get-credentials` fails | Cluster not provisioned | Wait for `terraform apply` to complete; check `az aks show` |
| Pod in `Pending` state | Node not ready / insufficient resources | `kubectl describe pod <name>` → check Events section |
| Pod in `CrashLoopBackOff` | Container startup failure | `kubectl logs <pod-name>` |
| `helm upgrade` fails — secret already exists | Prior partial install | `kubectl delete secret demo-app-secret; helm upgrade --install ...` |
| OMS agent pods not running | Container Insights not enabled | Verify `terraform apply` ran after Phase 4; `kubectl get pods -n kube-system` |
| ADO pipeline fails — service connection not found | `sc-azure-poc` not created | Create service connection per Section 3c |
| ADO pipeline fails — variable not found | Variable group not linked | Link `vg-aks-poc-dev` to the pipeline |
| `terraform validate` fails — module not found | `.terraform/` missing | Run `terraform init` first |
| AKS node shows `NotReady` after cluster start | Node pool warming up | Wait 2–3 min; `kubectl get nodes --watch` |

---

## 7. Future Phases Overview

The POC foundation is now complete. Future work builds on this base:

| Phase | Description |
|-------|------------|
| Container Insights | Already wired — `terraform apply` enables OMS agent on the running cluster |
| Azure Key Vault CSI | Replace `secret.yaml` placeholder with `SecretProviderClass` |
| AI Troubleshooting Agents | Deploy agent pods to AKS; connect to Log Analytics for log querying |
| Automated Diagnostics | Add runbook automation triggered by Azure Monitor alerts |
| Incident Root Cause Analysis | AI agent queries Container Insights data, surfaces pod/node anomalies |

---

*Runbook last updated: Phase 7 (2026-07-15). See [AGENT_CONTEXT.md](../AGENT_CONTEXT.md) for complete project history.*


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
