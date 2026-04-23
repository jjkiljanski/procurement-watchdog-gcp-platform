################################################################################
# Variables — Prod Environment
################################################################################

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "naming_prefix" {
  type    = string
  default = "procwatch"
}

variable "bucket_location" {
  type    = string
  default = "EU"
}

variable "network_name" {
  type    = string
  default = "default"
}

variable "dataproc_subnet_cidr" {
  type    = string
  default = "10.100.0.0/24"
}

variable "downloader_image_tag" {
  description = "Pin to a specific release tag in prod."
  type        = string
  default     = "latest"
}

variable "dataproc_container_image" {
  description = "Full Artifact Registry URI for the Dataproc Spark container. Required for the pipeline to run."
  type        = string
  default     = ""
}

variable "bq_location" {
  type    = string
  default = "EU"
}

variable "bq_silver_dataset_id" {
  type    = string
  default = "procurement_silver"
}

variable "bq_obs_dataset_id" {
  type    = string
  default = "procurement_obs"
}

variable "schedule_cron" {
  description = "Cron schedule for the daily pipeline (UTC)."
  type        = string
  default     = "0 3 * * *"
}

variable "time_zone" {
  type    = string
  default = "Europe/Warsaw"
}
