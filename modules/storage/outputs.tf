output "bucket_names" {
  description = "Map of layer name to bucket name."
  value       = { for k, v in google_storage_bucket.buckets : k => v.name }
}

output "bucket_urls" {
  description = "Map of layer name to gs:// URI."
  value       = { for k, v in google_storage_bucket.buckets : k => "gs://${v.name}" }
}

output "bucket_self_links" {
  description = "Map of layer name to bucket self_link."
  value       = { for k, v in google_storage_bucket.buckets : k => v.self_link }
}
