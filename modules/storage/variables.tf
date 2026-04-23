variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)."
  type        = string
}

variable "bucket_location" {
  description = "GCS bucket location (region or multi-region, e.g. EU)."
  type        = string
  default     = "EU"
}

variable "force_destroy" {
  description = "Allow Terraform to destroy the bucket even when it contains objects."
  type        = bool
  default     = false
}
