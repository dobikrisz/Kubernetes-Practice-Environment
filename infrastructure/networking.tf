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

resource "google_compute_router" "nat_router" {
  name    = "k8s-router"
  network = google_compute_network.vpc_network.id
  region  = var.REGION
}

resource "google_compute_router_nat" "nat_gateway" {
  name                               = "k8s-nat-gateway"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#resource "google_compute_firewall" "allow_egress_to_internet" {
#  name    = "allow-egress-to-internet"
#  network = google_compute_network.vpc_network.id
#
#  allow {
#    protocol = "tcp"
#    ports    = ["0-65535"]
#  }
#  allow {
#    protocol = "udp"
#    ports    = ["0-65535"]
#  }
#  allow {
#    protocol = "icmp"
#  }
#
#  direction = "EGRESS"
#
#  destination_ranges = ["0.0.0.0/0"] 
#}

resource "google_compute_firewall" "allow_k8s_api_from_jumpbox" {
  name    = "allow-k8s-api-from-jumpbox"
  network = google_compute_network.vpc_network.id

  direction = "INGRESS"
  source_ranges = [google_compute_subnetwork.k8s-subnet.ip_cidr_range]
  target_tags   = ["kubernetes-server"]

  allow {
    protocol = "all"
  }

  priority = 1000
}

resource "google_compute_firewall" "allow-internal-ssh" {
  name    = "allow-internal-ssh"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }

  target_tags = ["kubernetes-server"]
  source_ranges = [google_compute_subnetwork.k8s-subnet.ip_cidr_range]
}

resource "google_compute_firewall" "external-ssh" {
  name    = "allow-external-ssh"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["kubernetes-server"]
  source_ranges = ["0.0.0.0/0"]
}