################################################################################
# Storage Module — GCS Buckets for Medallion Lakehouse
#
# Creates buckets for each layer (bronze_raw, bronze, silver, gold) plus
# operational buckets (state, artifacts). All buckets use uniform bucket-level
# access and deterministic naming with environment prefix.
################################################################################

locals {
  bucket_definitions = {
    bronze_raw = {
      versioning      = false
      lifecycle_age   = var.bronze_raw_lifecycle_age_days
      storage_class   = "STANDARD"
    }
    bronze = {
      versioning      = false
      lifecycle_age   = var.bronze_lifecycle_age_days
      storage_class   = "STANDARD"
    }
    silver = {
      versioning      = false
      lifecycle_age   = var.silver_lifecycle_age_days
      storage_class   = "STANDARD"
    }
    gold = {
      versioning      = false
      lifecycle_age   = var.gold_lifecycle_age_days
      storage_class   = "STANDARD"
    }
    state = {
      versioning      = true
      lifecycle_age   = 0  # no lifecycle deletion
      storage_class   = "STANDARD"
    }
    artifacts = {
      versioning      = true
      lifecycle_age   = 0
      storage_class   = "STANDARD"
    }
  }
}

resource "google_storage_bucket" "buckets" {
  for_each = local.bucket_definitions

  name     = "${var.naming_prefix}-${each.key}-${var.environment}"
  project  = var.project_id
  location = var.bucket_location

  storage_class               = each.value.storage_class
  uniform_bucket_level_access = true
  force_destroy               = var.environment == "dev" ? true : false

  dynamic "versioning" {
    for_each = each.value.versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_age > 0 ? [1] : []
    content {
      condition {
        age = each.value.lifecycle_age
      }
      action {
        type          = "SetStorageClass"
        storage_class = "NEARLINE"
      }
    }
  }

  labels = {
    environment = var.environment
    layer       = each.key
    managed_by  = "terraform"
  }
}
