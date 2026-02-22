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

variable "launcher_sa_email" {
  description = "Service account email for the launcher."
  type        = string
}

variable "pipeline_runtime_sa_email" {
  description = "Service account email for Dataproc Serverless batch jobs."
  type        = string
}

variable "artifact_registry_url" {
  description = "Artifact Registry repository URL."
  type        = string
}

variable "artifacts_bucket_url" {
  description = "gs:// URL of the artifacts bucket."
  type        = string
}

variable "bronze_raw_bucket_url" {
  description = "gs:// URL of the bronze_raw bucket."
  type        = string
}

variable "bronze_bucket_url" {
  description = "gs:// URL of the bronze bucket."
  type        = string
}

variable "silver_bucket_url" {
  description = "gs:// URL of the silver bucket."
  type        = string
}

variable "gold_bucket_url" {
  description = "gs:// URL of the gold bucket."
  type        = string
}

variable "state_bucket_url" {
  description = "gs:// URL of the state bucket."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for the launcher container."
  type        = string
  default     = "latest"
}

variable "cpu_limit" {
  description = "CPU limit."
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit."
  type        = string
  default     = "512Mi"
}

variable "request_timeout" {
  description = "Request timeout."
  type        = string
  default     = "300s"
}

variable "spark_properties" {
  description = "Map of Spark configuration properties passed to batch jobs."
  type        = map(string)
  default     = {}
}
