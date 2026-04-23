variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the subnetwork."
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network to create the subnet in."
  type        = string
  default     = "default"
}

variable "subnet_cidr" {
  description = "CIDR range for the Dataproc subnet. Must not overlap with existing subnets."
  type        = string
  default     = "10.100.0.0/24"
}
