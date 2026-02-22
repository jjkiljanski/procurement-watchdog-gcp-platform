################################################################################
# Terraform Backend — Dev
#
# Uses a GCS bucket for remote state. The state bucket must be created
# manually before first `terraform init`:
#
#   gsutil mb -p <PROJECT_ID> -l EU gs://<PREFIX>-tfstate-dev
#   gsutil versioning set on gs://<PREFIX>-tfstate-dev
################################################################################

terraform {
  backend "gcs" {
    bucket = ""  # Set in dev.tfvars or via -backend-config
    prefix = "procurement-watchdog/dev"
  }
}
