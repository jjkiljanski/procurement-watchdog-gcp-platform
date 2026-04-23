output "dataproc_subnet_self_link" {
  description = "Self-link of the Dataproc subnet (pass to DATAPROC_SUBNET Airflow variable)."
  value       = google_compute_subnetwork.dataproc.self_link
}

output "dataproc_subnet_name" {
  description = "Name of the Dataproc subnet."
  value       = google_compute_subnetwork.dataproc.name
}
