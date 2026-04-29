################################################################################
# Variables — Dev Environment
################################################################################

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for compute resources (Dataproc, Cloud Run, Workflows)."
  type        = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "naming_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "procwatch"
}

variable "bucket_location" {
  description = "GCS bucket location. Should match bq_location."
  type        = string
  default     = "EU"
}

variable "network_name" {
  description = "VPC network to create the Dataproc subnet in."
  type        = string
  default     = "default"
}

variable "dataproc_subnet_cidr" {
  description = "CIDR for the Dataproc Serverless subnet."
  type        = string
  default     = "10.100.0.0/24"
}



variable "bq_location" {
  description = "BigQuery dataset location. Should match bucket_location."
  type        = string
  default     = "EU"
}

variable "bq_silver_dataset_id" {
  type    = string
  default = "procurement_silver"
}

variable "bq_obs_dataset_id" {
  type    = string
  default = "procurement_obs"
}

variable "schedule_cron" {
  description = "Cron schedule for the daily pipeline (UTC). Default: 03:00 UTC daily."
  type        = string
  default     = "0 3 * * *"
}

variable "time_zone" {
  description = "IANA time zone shown in Cloud Scheduler UI (cron is always UTC)."
  type        = string
  default     = "Europe/Warsaw"
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to impersonate the CI SA via WIF."
  type        = string
}

variable "backfill_start_date" {
  description = "First date (YYYY-MM-DD, inclusive) of the CI-triggered backfill on release tags."
  type        = string
}

variable "billing_account" {
  description = "GCP billing account ID attached to this project (format: XXXXXX-XXXXXX-XXXXXX). Used for the budget alert."
  type        = string
}

variable "alert_email" {
  description = "Email address for pipeline failure and budget alerts."
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly spend cap in the billing account's currency. Alerts fire at 80% and 100%."
  type        = number
  default     = 20
}
