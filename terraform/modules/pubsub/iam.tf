resource "google_pubsub_topic_iam_member" "relay_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.topics["video.received"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.relay_sa_email}"
}
