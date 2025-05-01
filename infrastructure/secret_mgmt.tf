resource "tls_private_key" "jumpbox_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_secret_manager_secret" "ssh_private_key" {
  secret_id     = "ssh-private-key"
  replication {
    auto {
    }
  }
  depends_on = [ google_project_service.secret_manager ]
}

resource "google_secret_manager_secret_version" "ssh_private_key_version" {
  secret      = google_secret_manager_secret.ssh_private_key.id
  secret_data = tls_private_key.jumpbox_key.private_key_pem
}

resource "google_secret_manager_secret_iam_member" "access" {
  secret_id = google_secret_manager_secret.ssh_private_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_compute_instance.jumpbox.service_account[0].email}"
}


