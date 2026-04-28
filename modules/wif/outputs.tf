output "ci_service_account_email" {
  description = "CI service account email — use as SERVICE_ACCOUNT in the google-github-actions/auth step."
  value       = google_service_account.ci.email
}

output "wif_provider" {
  description = "Full WIF provider resource name — use as WORKLOAD_IDENTITY_PROVIDER in the google-github-actions/auth step."
  value       = google_iam_workload_identity_pool_provider.github.name
}
