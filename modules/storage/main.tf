resource "google_storage_bucket" "lakehouse" {
  name          = "${var.project_id}-lakehouse"
  project       = var.project_id
  location      = var.bucket_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
