resource "google_compute_network" "vpc_network" {
  name                    = "k8s-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "k8s-subnet" {
  name          = "log-test-subnetwork"
  ip_cidr_range = "10.2.0.0/28"
  region        = "europe-west3"
  network       = google_compute_network.vpc_network.id

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}