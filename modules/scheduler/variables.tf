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

variable "backfill_schedule_cron" {
  description = "Cron expression for the backfill scheduler."
  type        = string
  default     = "0 */2 * * *"  # Every 2 hours
}

variable "transformation_schedule_cron" {
  description = "Cron expression for the transformation scheduler."
  type        = string
  default     = "30 6 * * *"  # Daily at 06:30
}

variable "time_zone" {
  description = "Time zone for scheduler (IANA format)."
  type        = string
  default     = "Europe/Warsaw"
}

variable "dispatcher_service_url" {
  description = "URL of the dispatcher Cloud Run service."
  type        = string
}

variable "launcher_service_url" {
  description = "URL of the launcher Cloud Run service."
  type        = string
}

variable "scheduler_invoker_sa_email" {
  description = "Service account email for Cloud Scheduler OIDC tokens."
  type        = string
}
