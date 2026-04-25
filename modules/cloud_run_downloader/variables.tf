variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run Job."
  type        = string
}

variable "environment" {
  description = "Environment label (dev, prod)."
  type        = string
}

variable "job_name" {
  description = "Cloud Run Job name. Referenced by the Cloud Workflows orchestration as downloader_job_name."
  type        = string
  default     = "bzp-downloader"
}

variable "downloader_sa_email" {
  description = "Service account email for the Cloud Run Job."
  type        = string
}

variable "lakehouse_bucket" {
  description = "Name of the lakehouse GCS bucket (without gs:// prefix)."
  type        = string
}

variable "job_timeout" {
  description = "Maximum duration for a single job execution."
  type        = string
  default     = "3600s"
}

variable "max_retries" {
  description = "Number of retries on task failure."
  type        = number
  default     = 2
}

variable "cpu_limit" {
  description = "CPU limit for the container."
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for the container."
  type        = string
  default     = "1Gi"
}

variable "bq_obs_dataset_id" {
  description = "BigQuery dataset ID for observability tables (pipeline_runs, dq_metrics)."
  type        = string
  default     = "procurement_obs"
}
