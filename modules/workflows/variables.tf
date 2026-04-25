variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the workflow and scheduler."
  type        = string
}

variable "environment" {
  description = "Environment label (dev, prod)."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "orchestrator_sa_email" {
  description = "Service account email that the workflow runs as (from iam module)."
  type        = string
}

variable "lakehouse_bucket" {
  description = "Lakehouse GCS bucket name (without gs://)."
  type        = string
}

variable "pipeline_sa_email" {
  description = "Pipeline runtime SA email used for Dataproc batch submissions."
  type        = string
}

variable "dataproc_subnet_self_link" {
  description = "Self-link of the Dataproc subnet (from network module)."
  type        = string
}


variable "downloader_job_name" {
  description = "Cloud Run Job name for the BZP downloader."
  type        = string
  default     = "bzp-downloader"
}

variable "bq_silver_dataset_id" {
  description = "BigQuery dataset ID for silver layer."
  type        = string
  default     = "procurement_silver"
}

variable "bq_obs_dataset_id" {
  description = "BigQuery dataset ID for observability."
  type        = string
  default     = "procurement_obs"
}

variable "schedule_cron" {
  description = "Cron schedule for the daily pipeline trigger (UTC)."
  type        = string
  default     = "0 3 * * *"
}

variable "time_zone" {
  description = "IANA time zone for Cloud Scheduler display (does not affect cron — cron is always UTC)."
  type        = string
  default     = "Europe/Warsaw"
}
