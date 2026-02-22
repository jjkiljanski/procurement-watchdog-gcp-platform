output "service_name" {
  description = "Cloud Run service name for the dispatcher."
  value       = google_cloud_run_v2_service.dispatcher.name
}

output "service_url" {
  description = "URL of the dispatcher Cloud Run service."
  value       = google_cloud_run_v2_service.dispatcher.uri
}
