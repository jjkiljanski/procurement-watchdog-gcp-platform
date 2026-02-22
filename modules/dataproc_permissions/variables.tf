variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "pipeline_runtime_sa_email" {
  description = "Pipeline runtime service account email."
  type        = string
}

variable "enable_bigquery_access" {
  description = "Whether to grant BigQuery access to the pipeline SA."
  type        = bool
  default     = false
}
