variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment label (dev, prod)."
  type        = string
}

variable "bq_location" {
  description = "BigQuery dataset location. Should match the GCS bucket location."
  type        = string
  default     = "EU"
}

variable "silver_dataset_id" {
  description = "BigQuery dataset ID for the silver layer (external Iceberg tables)."
  type        = string
  default     = "procurement_silver"
}

variable "obs_dataset_id" {
  description = "BigQuery dataset ID for observability tables."
  type        = string
  default     = "procurement_obs"
}

variable "pipeline_sa_email" {
  description = "Pipeline runtime service account email (from iam module)."
  type        = string
}
