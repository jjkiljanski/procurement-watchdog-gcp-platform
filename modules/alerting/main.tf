################################################################################
# Alerting Module
#
# Provisions:
#   - Email notification channel (shared by both alerts below)
#   - Log-based alert: bzp-daily Cloud Workflow execution FAILED
#   - Billing budget: 80% and 100% threshold alerts on monthly spend
#
# Required APIs (caller must enable before invoking this module):
#   monitoring.googleapis.com
#   billingbudgets.googleapis.com
################################################################################

# --------------------------------------------------------------------------- #
# Shared email notification channel
# --------------------------------------------------------------------------- #

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Pipeline Alerts — ${var.environment}"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# --------------------------------------------------------------------------- #
# Log-based alert — bzp-daily workflow execution failure
#
# Cloud Workflows writes severity=ERROR log entries when an execution fails.
# notification_rate_limit caps email frequency at one per hour so a flapping
# workflow doesn't flood the inbox.
# --------------------------------------------------------------------------- #

resource "google_monitoring_alert_policy" "workflow_failure" {
  project      = var.project_id
  display_name = "[${var.environment}] bzp-daily workflow execution failed"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "bzp-daily execution FAILED"

    condition_matched_log {
      filter = <<-EOT
        resource.type="workflows.googleapis.com/Workflow"
        resource.labels.workflow_id="bzp-daily"
        severity=ERROR
      EOT
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  documentation {
    content   = "The **bzp-daily** Cloud Workflow execution failed in **${var.environment}**.\n\nCheck the execution logs: https://console.cloud.google.com/workflows/workflow/${var.project_id}/bzp-daily/executions"
    mime_type = "text/markdown"
  }
}

# --------------------------------------------------------------------------- #
# Billing budget — monthly spend cap
# --------------------------------------------------------------------------- #

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "[${var.environment}] Monthly budget"

  budget_filter {
    projects = ["projects/${data.google_project.project.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.monthly_budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.name
    ]
    disable_default_iam_recipients = false
  }
}
