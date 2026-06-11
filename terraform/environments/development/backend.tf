terraform {
  backend "gcs" {
    bucket = "apex-outbox-tf-state"
    prefix = "terraform/state/development"
  }
}
