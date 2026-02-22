################################################################################
# BigQuery Serving Module
#
# Creates a BigQuery dataset with external tables referencing Gold Parquet
# files in GCS. BigQuery is a SERVING LAYER ONLY — Gold in GCS is canonical.
#
# Optional views provide pre-built analytical aggregations for Looker Studio.
################################################################################

resource "google_bigquery_dataset" "serving" {
  dataset_id    = var.dataset_id
  project       = var.project_id
  location      = var.dataset_location
  friendly_name = "Procurement Watchdog — ${var.environment}"
  description   = "Serving layer for procurement analytics. External tables over Gold Parquet in GCS."

  default_table_expiration_ms = null  # External tables should not expire

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  dynamic "access" {
    for_each = var.dashboard_viewer_members
    content {
      role          = "READER"
      user_by_email = access.value
    }
  }

  # Ensure the default access (project owners/editors) is preserved.
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# --------------------------------------------------------------------------- #
# External Tables — Gold Layer
# --------------------------------------------------------------------------- #

resource "google_bigquery_table" "case_mart" {
  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "case_mart"
  project             = var.project_id
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["${var.gold_bucket_url}/case_mart/date=*//*.parquet"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "${var.gold_bucket_url}/case_mart/"
      require_partition_filter  = false
    }
  }

  labels = {
    layer      = "gold"
    mart       = "case"
    managed_by = "terraform"
  }
}

resource "google_bigquery_table" "buyer_mart" {
  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "buyer_mart"
  project             = var.project_id
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["${var.gold_bucket_url}/buyer_mart/date=*//*.parquet"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "${var.gold_bucket_url}/buyer_mart/"
      require_partition_filter  = false
    }
  }

  labels = {
    layer      = "gold"
    mart       = "buyer"
    managed_by = "terraform"
  }
}

resource "google_bigquery_table" "market_mart" {
  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "market_mart"
  project             = var.project_id
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["${var.gold_bucket_url}/market_mart/date=*//*.parquet"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "${var.gold_bucket_url}/market_mart/"
      require_partition_filter  = false
    }
  }

  labels = {
    layer      = "gold"
    mart       = "market"
    managed_by = "terraform"
  }
}

resource "google_bigquery_table" "signals_buyer_daily" {
  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "signals_buyer_daily"
  project             = var.project_id
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["${var.gold_bucket_url}/signals_buyer_daily/date=*//*.parquet"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "${var.gold_bucket_url}/signals_buyer_daily/"
      require_partition_filter  = false
    }
  }

  labels = {
    layer      = "gold"
    mart       = "signals"
    managed_by = "terraform"
  }
}

# --------------------------------------------------------------------------- #
# Optional Views
# --------------------------------------------------------------------------- #

resource "google_bigquery_table" "view_institution_summary" {
  count = var.create_views ? 1 : 0

  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "v_institution_summary"
  project             = var.project_id
  deletion_protection = false

  view {
    query = <<-SQL
      SELECT
        buyerName,
        COUNT(DISTINCT caseId)    AS total_cases,
        COUNT(*)                  AS total_notices,
        MIN(date)                 AS first_activity,
        MAX(date)                 AS last_activity
      FROM `${var.project_id}.${var.dataset_id}.buyer_mart`
      GROUP BY buyerName
    SQL
    use_legacy_sql = false
  }

  labels = {
    type       = "view"
    managed_by = "terraform"
  }

  depends_on = [google_bigquery_table.buyer_mart]
}

resource "google_bigquery_table" "view_risk_metrics" {
  count = var.create_views ? 1 : 0

  dataset_id          = google_bigquery_dataset.serving.dataset_id
  table_id            = "v_risk_metrics"
  project             = var.project_id
  deletion_protection = false

  view {
    query = <<-SQL
      SELECT
        date,
        COUNT(DISTINCT buyerName) AS active_buyers,
        COUNT(*)                  AS daily_signals,
        COUNTIF(signal_type = 'high_risk') AS high_risk_count
      FROM `${var.project_id}.${var.dataset_id}.signals_buyer_daily`
      GROUP BY date
      ORDER BY date DESC
    SQL
    use_legacy_sql = false
  }

  labels = {
    type       = "view"
    managed_by = "terraform"
  }

  depends_on = [google_bigquery_table.signals_buyer_daily]
}
