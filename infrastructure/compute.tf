locals {
  vm_image = "debian-cloud/debian-12-bookworm"
}

resource "google_service_account" "default" {
  account_id   = "kubernetes-vm-sa"
  display_name = "Custom SA for Kubernetes cluster host VM Instances"
}

resource "google_compute_instance" "default" {
  name         = "jumpbox"
  machine_type = "n1-standard-1"

  boot_disk {
    initialize_params {
      image = local.vm_image
      size = 10
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.id

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = file("../vm_config/jumpbox/startup.sh")
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["kubernetes-server"]
}

resource "google_compute_firewall" "default" {
  name    = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags = ["kubernetes-server"]
}