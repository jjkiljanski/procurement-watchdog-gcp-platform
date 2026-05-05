output "silver_dataset_id" {
  description = "BigQuery dataset ID for the silver layer."
  value       = google_bigquery_dataset.silver.dataset_id
}

output "obs_dataset_id" {
  description = "BigQuery dataset ID for observability."
  value       = google_bigquery_dataset.obs.dataset_id
}

output "iceberg_connection_id" {
  description = "BigQuery connection resource path for external Iceberg tables."
  value       = "${var.project_id}.${var.bq_location}.${google_bigquery_connection.iceberg.connection_id}"
}
