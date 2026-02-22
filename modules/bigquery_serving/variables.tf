variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID."
  type        = string
  default     = "procurement_serving"
}

variable "dataset_location" {
  description = "BigQuery dataset location (should match GCS bucket region)."
  type        = string
  default     = "EU"
}

variable "gold_bucket_url" {
  description = "gs:// URL of the gold GCS bucket."
  type        = string
}

variable "dashboard_viewer_members" {
  description = "List of email addresses to grant READER access for Looker Studio."
  type        = list(string)
  default     = []
}

variable "create_views" {
  description = "Whether to create optional analytical views."
  type        = bool
  default     = true
}
