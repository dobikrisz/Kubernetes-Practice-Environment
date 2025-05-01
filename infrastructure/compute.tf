locals {
  vm_image = "debian-cloud/debian-12"
}

resource "tls_private_key" "jumpbox_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_service_account" "default" {
  account_id   = "kubernetes-vm-sa"
  display_name = "Custom SA for Kubernetes cluster host VM Instances"
}

resource "google_compute_instance" "server" {
  name         = "server"
  machine_type = "n1-standard-1"

  boot_disk {
    initialize_params {
      image = local.vm_image
      size = 20
    }

  }

  network_interface {
    network = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.k8s-subnet.id
    
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "root:${tls_private_key.jumpbox_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("../vm_config/server/startup.sh", {})
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["kubernetes-server"]
}

resource "google_compute_instance" "node0" {
  name         = "node-0"
  machine_type = "n1-standard-1"

  boot_disk {
    initialize_params {
      image = local.vm_image
      size = 20
    }

  }

  network_interface {
    network = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.k8s-subnet.id
    
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "root:${tls_private_key.jumpbox_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("../vm_config/node-0/startup.sh", {})
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["kubernetes-server"]
}

resource "google_compute_instance" "node1" {
  name         = "node-1"
  machine_type = "n1-standard-1"

  boot_disk {
    initialize_params {
      image = local.vm_image
      size = 20
    }

  }

  network_interface {
    network = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.k8s-subnet.id
    
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "root:${tls_private_key.jumpbox_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("../vm_config/node-1/startup.sh", {})
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["kubernetes-server"]
}

resource "google_compute_instance" "jumpbox" {
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
    subnetwork = google_compute_subnetwork.k8s-subnet.id
    
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    server_ip = google_compute_instance.server.network_interface[0].network_ip
    node0_ip  = google_compute_instance.node0.network_interface[0].network_ip
    node1_ip  = google_compute_instance.node1.network_interface[0].network_ip
    ssh-keys = "root:${tls_private_key.jumpbox_key.public_key_openssh}"
    private_key = tls_private_key.jumpbox_key.private_key_pem
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