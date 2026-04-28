################################################################################
# Variables — Prod Environment
################################################################################

variable "org_id" {
  description = "GCP organization ID. Used to create the prod project."
  type        = string
}

variable "billing_account" {
  description = "GCP billing account ID to attach to the prod project (format: XXXXXX-XXXXXX-XXXXXX)."
  type        = string
}

variable "project_id" {
  description = "GCP project ID for prod. Must be globally unique."
  type        = string
}

variable "region" {
  description = "GCP region for compute resources."
  type        = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "naming_prefix" {
  type    = string
  default = "procwatch"
}

variable "bucket_location" {
  type    = string
  default = "EU"
}

variable "network_name" {
  type    = string
  default = "default"
}

variable "dataproc_subnet_cidr" {
  type    = string
  default = "10.100.0.0/24"
}

variable "bq_location" {
  type    = string
  default = "EU"
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
  description = "Cron schedule for the daily pipeline (UTC)."
  type        = string
  default     = "0 3 * * *"
}

variable "time_zone" {
  type    = string
  default = "Europe/Warsaw"
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to impersonate the CI SA via WIF."
  type        = string
}

variable "backfill_start_date" {
  description = "First date (YYYY-MM-DD, inclusive) of the CI-triggered backfill on release tags."
  type        = string
}
