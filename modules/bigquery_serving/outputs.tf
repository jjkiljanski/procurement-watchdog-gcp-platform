output "dataset_id" {
  description = "BigQuery dataset ID."
  value       = google_bigquery_dataset.serving.dataset_id
}

output "dataset_self_link" {
  description = "BigQuery dataset self link."
  value       = google_bigquery_dataset.serving.self_link
}

output "table_ids" {
  description = "List of external table IDs created."
  value = [
    google_bigquery_table.case_mart.table_id,
    google_bigquery_table.buyer_mart.table_id,
    google_bigquery_table.market_mart.table_id,
    google_bigquery_table.signals_buyer_daily.table_id,
  ]
}
