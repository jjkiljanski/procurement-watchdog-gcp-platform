variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "dispatcher_sa_email" {
  description = "Service account email for the dispatcher."
  type        = string
}

variable "state_bucket_url" {
  description = "gs:// URL of the state bucket."
  type        = string
}

variable "downloader_job_name" {
  description = "Name of the downloader Cloud Run Job."
  type        = string
}

variable "artifact_registry_url" {
  description = "Artifact Registry repository URL."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for the dispatcher container."
  type        = string
  default     = "latest"
}

variable "cpu_limit" {
  description = "CPU limit for dispatcher container."
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for dispatcher container."
  type        = string
  default     = "512Mi"
}

variable "request_timeout" {
  description = "Request timeout for the dispatcher service."
  type        = string
  default     = "300s"
}

variable "max_backfill_concurrency" {
  description = "Maximum concurrent downloader jobs."
  type        = number
  default     = 3
}

variable "backfill_start_date" {
  description = "Earliest date for backfill window (YYYY-MM-DD)."
  type        = string
  default     = "2024-01-01"
}
