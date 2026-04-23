variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for service account IDs."
  type        = string
}

variable "lakehouse_bucket" {
  description = "Name of the lakehouse GCS bucket (from storage module)."
  type        = string
}
