# AKS AI Troubleshooting POC

A Proof of Concept platform built on Azure Kubernetes Service (AKS), designed as the foundation for AI-powered troubleshooting agents.

## Current Status

See [AGENT_CONTEXT.md](./AGENT_CONTEXT.md) for current phase, decisions, and open questions.

## Repository Structure

```
/
├── AGENT_CONTEXT.md                  # Project context, decisions, assumptions (read this first)
├── terraform/
│   ├── bootstrap/                    # One-time remote state backend setup
│   ├── modules/                      # Reusable Terraform modules (networking, aks, identity, monitoring)
│   └── environments/dev/             # Dev environment root configuration
├── helm/
│   └── demo-app/                     # Sample application Helm chart
├── pipelines/                        # Azure DevOps YAML pipeline files
├── scripts/                          # One-off operational scripts
└── docs/                             # Runbooks and design documents
```

## Quick Start

> Prerequisites and full setup steps are in [docs/runbook.md](./docs/runbook.md).
> Azure infrastructure architecture and diagrams are in [docs/architecture.md](./docs/architecture.md).

1. Read `AGENT_CONTEXT.md`
2. Run `scripts/bootstrap-state.sh` (once only — creates Terraform remote state backend)
3. Configure `terraform/environments/dev/terraform.tfvars` from the example file
4. Run `terraform init` + `terraform apply` from `terraform/environments/dev/`
5. Run `az aks get-credentials` (command shown in Terraform outputs)
6. Deploy the sample app: `helm upgrade --install demo-app ./helm/demo-app -f helm/demo-app/values-dev.yaml`

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Cloud | Azure |
| Container platform | Azure Kubernetes Service (AKS) |
| Infrastructure as Code | Terraform |
| Application deployment | Helm |
| CI/CD | Azure DevOps YAML pipelines |
| Observability | Azure Monitor / Log Analytics (Phase 4) |

## Future Phases

- **Phase 4** — Container Insights + Azure Monitor observability
- **Phase 5+** — AI troubleshooting agents, automated diagnostics, incident analysis
