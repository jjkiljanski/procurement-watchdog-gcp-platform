output "silver_dataset_id" {
  description = "BigQuery dataset ID for the silver layer."
  value       = google_bigquery_dataset.silver.dataset_id
}

output "obs_dataset_id" {
  description = "BigQuery dataset ID for observability."
  value       = google_bigquery_dataset.obs.dataset_id
}
