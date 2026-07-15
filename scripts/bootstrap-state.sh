#!/usr/bin/env bash
# scripts/bootstrap-state.sh
# One-time setup of the Terraform remote state backend.
# Run ONCE before any 'terraform init' command.
# Idempotent: safe to re-run if resources already exist.
#
# Usage:
#   bash scripts/bootstrap-state.sh [LOCATION]
#
# Requires: Azure CLI (az) logged in with Contributor on the subscription.
# On Windows: run from Git Bash, WSL, or Azure Cloud Shell.

set -euo pipefail

RESOURCE_GROUP="rg-tfstate-poc"
LOCATION="${1:-eastus}"
CONTAINER_NAME="tfstate"

# Derive a 4-char deterministic suffix from the subscription ID (hex chars only)
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUFFIX=$(echo -n "$SUBSCRIPTION_ID" | tr -d '-' | cut -c1-4)
STORAGE_ACCOUNT_NAME="stpocaksstate${SUFFIX}"

echo "===================================================================="
echo " Bootstrap: Terraform remote state backend"
echo "===================================================================="
echo "  Subscription   : ${SUBSCRIPTION_ID}"
echo "  Resource Group : ${RESOURCE_GROUP}"
echo "  Location       : ${LOCATION}"
echo "  Storage Account: ${STORAGE_ACCOUNT_NAME}"
echo "  Container      : ${CONTAINER_NAME}"
echo "===================================================================="
echo ""

# ── Resource Group ─────────────────────────────────────────────────────────
echo "--> Creating resource group '${RESOURCE_GROUP}'..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output none
echo "    Done."

# ── Storage Account ────────────────────────────────────────────────────────
echo "--> Creating storage account '${STORAGE_ACCOUNT_NAME}'..."
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output none
echo "    Done."

# ── Blob Container ─────────────────────────────────────────────────────────
echo "--> Creating blob container '${CONTAINER_NAME}'..."
ACCOUNT_KEY=$(az storage account keys list \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[0].value" \
  --output tsv)

az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --account-key "${ACCOUNT_KEY}" \
  --output none
echo "    Done."

echo ""
echo "===================================================================="
echo " Bootstrap complete. Storage account: ${STORAGE_ACCOUNT_NAME}"
echo "===================================================================="
echo ""
echo " Next steps:"
echo ""
echo " 1. Copy the tfvars example and fill in your values:"
echo "      cp terraform/environments/dev/terraform.tfvars.example \\"
echo "         terraform/environments/dev/terraform.tfvars"
echo ""
echo " 2. Initialize Terraform (from terraform/environments/dev/):"
echo "      terraform init \\"
echo "        -backend-config=\"storage_account_name=${STORAGE_ACCOUNT_NAME}\""
echo ""
echo " 3. Validate:"
echo "      terraform validate"
echo ""
echo " NOTE: The bootstrap storage account ('${STORAGE_ACCOUNT_NAME}') is"
echo "       NOT managed by the main Terraform state. Delete it manually"
echo "       if you need a full teardown."
echo "===================================================================="
