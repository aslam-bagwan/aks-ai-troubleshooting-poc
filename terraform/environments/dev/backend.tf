# terraform/environments/dev/backend.tf
# Remote state backend configuration.
# The storage_account_name is NOT hardcoded here — pass it at init time:
#
#   terraform init -backend-config="storage_account_name=<name>"
#
# Run scripts/bootstrap-state.sh first to create the storage account.
# The script prints the exact terraform init command to use.

terraform {
  backend "azurerm" {
    resource_group_name = "rg-tfstate-poc"
    container_name      = "tfstate"
    key                 = "dev/terraform.tfstate"
    # storage_account_name — supplied via -backend-config at init time (not committed)
  }
}
