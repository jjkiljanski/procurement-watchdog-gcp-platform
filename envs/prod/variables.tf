################################################################################
# Variables — Prod Environment
################################################################################

# --------------------------------------------------------------------------- #
# Required
# --------------------------------------------------------------------------- #

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for compute resources."
  type        = string
}

# --------------------------------------------------------------------------- #
# Naming & Environment
# --------------------------------------------------------------------------- #

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "naming_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "procwatch"
}

# --------------------------------------------------------------------------- #
# Storage
# --------------------------------------------------------------------------- #

variable "bucket_location" {
  description = "GCS bucket location."
  type        = string
  default     = "EU"
}

variable "bronze_raw_lifecycle_age_days" {
  description = "Days before bronze_raw transitions to Nearline. 0 = disabled."
  type        = number
  default     = 90
}

variable "bronze_lifecycle_age_days" {
  description = "Days before bronze transitions to Nearline. 0 = disabled."
  type        = number
  default     = 180
}

variable "silver_lifecycle_age_days" {
  description = "Days before silver transitions to Nearline. 0 = disabled."
  type        = number
  default     = 0
}

variable "gold_lifecycle_age_days" {
  description = "Days before gold transitions to Nearline. 0 = disabled."
  type        = number
  default     = 0
}

# --------------------------------------------------------------------------- #
# Container Images
# --------------------------------------------------------------------------- #

variable "image_tag" {
  description = "Docker image tag for all pipeline containers."
  type        = string
  default     = "latest"
}

# --------------------------------------------------------------------------- #
# Scheduler
# --------------------------------------------------------------------------- #

variable "backfill_schedule_cron" {
  description = "Cron for backfill dispatcher."
  type        = string
  default     = "0 * * * *"  # Every hour in prod
}

variable "transformation_schedule_cron" {
  description = "Cron for daily Spark transformation."
  type        = string
  default     = "30 6 * * *"  # Daily at 06:30
}

variable "scheduler_time_zone" {
  description = "Time zone for Cloud Scheduler."
  type        = string
  default     = "Europe/Warsaw"
}

# --------------------------------------------------------------------------- #
# Backfill
# --------------------------------------------------------------------------- #

variable "max_backfill_concurrency" {
  description = "Maximum concurrent downloader jobs during backfill."
  type        = number
  default     = 5
}

variable "backfill_start_date" {
  description = "Earliest date for the backfill window (YYYY-MM-DD)."
  type        = string
  default     = "2024-01-01"
}

# --------------------------------------------------------------------------- #
# Spark
# --------------------------------------------------------------------------- #

variable "spark_properties" {
  description = "Spark configuration properties for Dataproc Serverless."
  type        = map(string)
  default = {
    "spark.executor.memory"               = "8g"
    "spark.executor.cores"                = "4"
    "spark.dynamicAllocation.enabled"     = "true"
    "spark.dynamicAllocation.maxExecutors" = "20"
  }
}

# --------------------------------------------------------------------------- #
# BigQuery
# --------------------------------------------------------------------------- #

variable "enable_bigquery_serving" {
  description = "Whether to create BigQuery serving layer."
  type        = bool
  default     = true
}

variable "bigquery_dataset_id" {
  description = "BigQuery dataset ID."
  type        = string
  default     = "procurement_serving"
}

variable "dashboard_viewer_members" {
  description = "Email addresses granted BigQuery READER access for Looker Studio."
  type        = list(string)
  default     = []
}
