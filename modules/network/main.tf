################################################################################
# Network Module — Subnet for Dataproc Serverless
#
# Creates a dedicated subnetwork with Private Google Access enabled. Dataproc
# Serverless requires PGA so workers can reach GCS and BQ without a NAT gateway.
# The subnet is created inside the existing VPC specified by var.network_name
# (defaults to "default" which is present in most projects).
################################################################################

data "google_compute_network" "vpc" {
  name    = var.network_name
  project = var.project_id
}

resource "google_compute_subnetwork" "dataproc" {
  name                     = "${var.naming_prefix}-dataproc"
  project                  = var.project_id
  region                   = var.region
  network                  = data.google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Dataproc Serverless requires all-ports ingress within the subnet so Spark
# workers can register with the driver. The default VPC allow-internal rule
# only covers 10.128.0.0/9 and does not reach our custom CIDR.
resource "google_compute_firewall" "dataproc_internal" {
  name    = "${var.naming_prefix}-dataproc-internal"
  project = var.project_id
  network = data.google_compute_network.vpc.id

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.subnet_cidr]

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}
