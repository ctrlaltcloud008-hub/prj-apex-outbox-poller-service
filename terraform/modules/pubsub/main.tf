locals {
  default_lables = {
    team        = "apex"
    environment = var.environment
    managed_by  = "terraform"
  }

  topics = [
    "video.received",
    "video.received.dlq",
  ]
}


resource "google_pubsub_topic" "topics" {
  for_each = toset(local.topics)

  project = var.project_id
  name    = each.value

  message_retention_duration = var.message_retention_duration
  labels                     = local.default_lables
}
