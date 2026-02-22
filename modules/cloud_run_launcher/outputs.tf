output "service_name" {
  description = "Cloud Run service name for the launcher."
  value       = google_cloud_run_v2_service.launcher.name
}

output "service_url" {
  description = "URL of the launcher Cloud Run service."
  value       = google_cloud_run_v2_service.launcher.uri
}
