variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "dev or prod — used in display names."
  type        = string
}

variable "billing_account" {
  description = "GCP billing account ID (format: XXXXXX-XXXXXX-XXXXXX). Required for the budget resource."
  type        = string
}

variable "alert_email" {
  description = "Email address that receives pipeline failure and budget alerts."
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly spend cap in the billing account's currency. Alerts fire at 80% and 100% of this amount."
  type        = number
}
