module "pubsub" {
  source         = "../../modules/pubsub"
  project_id     = var.project_id
  project_region = var.project_region
  environment    = var.environment
  relay_sa_email = var.relay_sa_email
}

