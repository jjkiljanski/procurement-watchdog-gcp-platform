variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for service account IDs."
  type        = string
}

variable "bucket_names" {
  description = "Map of layer name to GCS bucket name (from storage module)."
  type        = map(string)
}

variable "dispatcher_service_name" {
  description = "Cloud Run service name for dispatcher (for invoker binding)."
  type        = string
  default     = ""
}

variable "launcher_service_name" {
  description = "Cloud Run service name for launcher (for invoker binding)."
  type        = string
  default     = ""
}
