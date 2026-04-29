variable "project_id" {
  description = "GCP project ID where the WIF pool and CI SA are created."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names (pool ID, SA account ID)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/name format (e.g. acme/procurement-watchdog-lakehouse)."
  type        = string
}

variable "lakehouse_bucket" {
  description = "Lakehouse GCS bucket name — CI SA gets objectAdmin on it."
  type        = string
}

variable "orchestrator_sa_id" {
  description = "Full resource ID of the orchestrator SA — CI SA needs serviceAccountUser on it to deploy workflows."
  type        = string
}

variable "downloader_sa_id" {
  description = "Full resource ID of the downloader SA — CI SA needs serviceAccountUser on it to update the Cloud Run job."
  type        = string
}

variable "scheduler_invoker_sa_id" {
  description = "Full resource ID of the scheduler invoker SA — CI SA needs serviceAccountUser on it to update the Cloud Scheduler job."
  type        = string
}
