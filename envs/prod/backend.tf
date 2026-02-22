################################################################################
# Terraform Backend — Prod
#
# Uses a GCS bucket for remote state. The state bucket must be created
# manually before first `terraform init`:
#
#   gsutil mb -p <PROJECT_ID> -l EU gs://<PREFIX>-tfstate-prod
#   gsutil versioning set on gs://<PREFIX>-tfstate-prod
################################################################################

terraform {
  backend "gcs" {
    bucket = ""  # Set in prod.tfvars or via -backend-config
    prefix = "procurement-watchdog/prod"
  }
}
