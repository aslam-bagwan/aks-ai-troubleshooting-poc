# AGENT_CONTEXT.md — AKS AI Troubleshooting POC

> Single source of truth for this project. Read this file in full at the start of every session before doing anything else.
> Never contains secrets, credentials, subscription/tenant IDs, or any sensitive value. Use placeholders (e.g., `<subscription-id>`).

---

## 1. Project Summary

A Proof of Concept platform built on Azure Kubernetes Service (AKS) to serve as the foundation for future AI-powered troubleshooting agents. **Current phase: Phase 0 complete / Phase 1 design complete — awaiting approval before implementation.**

Target stack: Azure · AKS · Terraform (IaC) · Helm (app deployment) · Azure DevOps YAML pipelines · Azure Monitor. Designed to be cost-effective on a personal Visual Studio subscription.

---

## 2. Standing Rules

### Planning Rules
- Do NOT write code initially.
- First create the architecture and implementation plan.
- Wait for approval before implementation.
- Do not make assumptions without clearly stating them — log every assumption in this file's consolidated assumptions log, not scattered inline in other documents.
- Ask questions only when required to proceed.

### Implementation Rules
After approval:
- Implement one phase at a time.
- Explain the changes before making them.
- Modify/create only required files.
- Avoid unnecessary files.
- Keep commits/changes small and reviewable.
- Stop after each phase and wait for approval.
- Update this file's phase log before stopping.

### Technical Rules
- Use Terraform best practices.
- Use modular Terraform design.
- Use AzureRM provider best practices.
- Keep Azure costs low.
- Avoid unnecessary high availability features.
- Avoid over-engineering.
- Design for future extensibility.
- Use secure defaults.
- Do not hardcode secrets.
- Prepare the structure for future Azure Key Vault integration.
- Keep Helm charts reusable.
- Keep pipelines modular and reusable.

---

## 3. Consolidated Assumptions Log

| # | Phase | Assumption | Status |
|---|-------|-----------|--------|
| A01 | Phase 0 | Repo created at `c:\Users\AslamBagwan\source\poc\aks-ai-troubleshooting-poc\` | approved |
| A02 | Phase 1 | Azure region: `eastus` — lowest-cost region with full AKS + Log Analytics + Monitor addon support | proposed |
| A03 | Phase 1 | Terraform remote state backend: Azure Storage Account + Blob container, bootstrapped via a one-time script | proposed |
| A04 | Phase 1 | AKS auth model: local K8s accounts + K8s RBAC (no Entra ID for POC) | proposed |
| A05 | Phase 1 | Node VM size: `Standard_B2s` (2 vCPU / 4 GB) · 1 node · budget ceiling ~$50/month | proposed |
| A06 | Phase 1 | Interim secrets: K8s Secret created from Helm values with `REPLACE_ME` placeholder; real value passed via `--set` CLI only, never committed | proposed |
| A07 | Phase 1 | ADO organization and project already exist; creating them is out of scope | proposed |
| A08 | Phase 1 | Container Insights / OMS addon deferred to Phase 4; Log Analytics Workspace created now (prepares hook, near-zero cost until data flows) | proposed |
| A09 | Phase 1 | Networking model: kubenet (simpler, no extra VNet CIDR constraints) | proposed |
| A10 | Phase 1 | Sample application: `nginx` (no secrets needed, cleanly validates deployment + service path) | proposed |

---

## 4. Key Decisions Log

| Decision | Chosen Option | Rationale | Phase | Date |
|----------|-------------|-----------|-------|------|
| Azure region | `eastus` | Lowest-cost, broadest service availability (AKS, Log Analytics, Container Insights). Trade-off: not closest geographically if user is in UK/EU, but acceptable for a POC. | Phase 1 | 2026-07-15 |
| Terraform state backend | Remote — Azure Storage Account (`stpocaksstate<suffix>`, container `tfstate`) | Enables CI/CD pipelines to share state; avoids local-state risks. Bootstrap chicken-and-egg handled by `scripts/bootstrap-state.sh` run once manually before `terraform init`. | Phase 1 | 2026-07-15 |
| AKS auth/identity model | Local K8s accounts + K8s RBAC | Lowest complexity for single-person POC. Entra ID adds cost, group/app registration overhead not warranted here. Trade-off: weaker identity governance — acceptable for POC, revisit before production. | Phase 1 | 2026-07-15 |
| Node pool budget ceiling | `Standard_B2s` × 1 node ≈ $34/month · target: **under $50/month total** | B2s covers 2-node basic workload; burstable CPU suits intermittent POC use. Auto-scaling disabled. Cluster can be stopped when idle to avoid compute costs. | Phase 1 | 2026-07-15 |
| Interim secrets story | K8s Secret via Helm values, placeholder `REPLACE_ME`, passed via `--set` at deploy time | No secrets committed. Explicit TODO comment in `secret.yaml` pointing to Key Vault CSI driver (future phase). | Phase 1 | 2026-07-15 |
| ADO prerequisites | Org/project assumed to exist; service connection `sc-azure-poc` assumed pre-created | Out of scope to script ADO org/project creation. Documented as manual prerequisite in runbook. | Phase 1 | 2026-07-15 |
| Observability hooks | Log Analytics Workspace created now; Container Insights addon deferred to Phase 4 | Avoids over-engineering Phase 1 while keeping the extensibility hook. No cost incurred until data flows. | Phase 1 | 2026-07-15 |

---

## 5. Repository Map

> Updated as folders/files are added.

| Path | Purpose |
|------|---------|
| `/AGENT_CONTEXT.md` | This file — project context, decisions, assumptions (git-tracked) |
| `/docs/phase1-design.md` | Phase 1 full solution design document |
| `/terraform/bootstrap/` | One-time remote state backend bootstrap (run before `terraform init`) |
| `/terraform/modules/networking/` | VNet, subnets, NSG Terraform module |
| `/terraform/modules/identity/` | User-assigned Managed Identity + RBAC module |
| `/terraform/modules/monitoring/` | Log Analytics Workspace module |
| `/terraform/modules/aks/` | AKS cluster + node pool module |
| `/terraform/environments/dev/` | Dev environment root configuration (providers, backend, main, vars, outputs) |
| `/helm/demo-app/` | Reusable sample application Helm chart |
| `/pipelines/` | Azure DevOps YAML pipeline files |
| `/pipelines/templates/` | Reusable pipeline step templates |
| `/scripts/bootstrap-state.sh` | One-time script to create Terraform remote state backend |
| `/docs/runbook.md` | Manual setup steps and local validation guide |

---

## 6. Phase Log

| Phase | Objective | Files Touched | Validation | Outcome | Open Follow-ups |
|-------|-----------|--------------|-----------|---------|----------------|
| Phase 0 | Create AGENT_CONTEXT.md, initialize repo | `AGENT_CONTEXT.md`, `.gitignore` | File exists, git-tracked | Complete | — |
| Phase 1 (Design) | Solution design document | `docs/phase1-design.md`, `AGENT_CONTEXT.md` | Design reviewed and approved | Awaiting approval | See Open Questions |

---

## 7. Open Questions

| # | Question | Blocking? |
|---|----------|----------|
| Q01 | Confirm Azure region: `eastus` acceptable, or prefer a specific region (e.g., `uksouth`, `westeurope`)? | No — defaulting to `eastus` unless redirected |
| Q02 | ADO organization/project name — needed when implementing pipeline files. Not blocking Phase 1 design. | No — ask before Phase 6 |
| Q03 | Should `Standard_B2s` be the VM size, or is a smaller/larger size preferred for the budget target? | No — defaulting to B2s unless redirected |
