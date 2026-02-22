variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "downloader_sa_email" {
  description = "Service account email for the downloader job."
  type        = string
}

variable "bronze_raw_bucket_url" {
  description = "gs:// URL of the bronze_raw bucket."
  type        = string
}

variable "state_bucket_url" {
  description = "gs:// URL of the state bucket."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for the downloader container."
  type        = string
  default     = "latest"
}

variable "create_artifact_registry" {
  description = "Whether to create the Artifact Registry repository."
  type        = bool
  default     = true
}

variable "artifact_registry_url" {
  description = "Existing Artifact Registry URL (if create_artifact_registry=false)."
  type        = string
  default     = ""
}

variable "cpu_limit" {
  description = "CPU limit for downloader container."
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for downloader container."
  type        = string
  default     = "1Gi"
}

variable "job_timeout" {
  description = "Job timeout duration (e.g. 1800s)."
  type        = string
  default     = "1800s"
}

variable "max_retries" {
  description = "Maximum retries per failed task."
  type        = number
  default     = 2
}
