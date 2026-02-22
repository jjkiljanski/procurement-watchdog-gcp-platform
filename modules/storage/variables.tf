variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for all resource names."
  type        = string
}

variable "bucket_location" {
  description = "GCS bucket location (region or multi-region)."
  type        = string
  default     = "EU"
}

variable "bronze_raw_lifecycle_age_days" {
  description = "Days before bronze_raw objects transition to Nearline. 0 = disabled."
  type        = number
  default     = 90
}

variable "bronze_lifecycle_age_days" {
  description = "Days before bronze objects transition to Nearline. 0 = disabled."
  type        = number
  default     = 0
}

variable "silver_lifecycle_age_days" {
  description = "Days before silver objects transition to Nearline. 0 = disabled."
  type        = number
  default     = 0
}

variable "gold_lifecycle_age_days" {
  description = "Days before gold objects transition to Nearline. 0 = disabled."
  type        = number
  default     = 0
}
