output "bucket_name" {
  description = "Name of the lakehouse GCS bucket."
  value       = google_storage_bucket.lakehouse.name
}

output "bucket_url" {
  description = "gs:// URI of the lakehouse bucket."
  value       = "gs://${google_storage_bucket.lakehouse.name}"
}
