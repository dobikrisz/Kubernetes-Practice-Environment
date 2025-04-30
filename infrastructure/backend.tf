terraform {
  backend "gcs" {
    bucket  = var.BUCKET
    prefix  = "terraform/state"
  }
}
