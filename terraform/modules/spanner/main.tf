locals {
  default_labels = {
    team        = "apex"
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Adds the outbox_relay_checkpoints table and outbox_stream Change Stream to the
# existing Spanner database. Does not create or modify the database itself.
resource "google_spanner_database_ddl" "outbox_relay" {
  project  = var.project_id
  instance = var.spanner_instance
  database = var.spanner_database

  ddl = [
    <<-EOT
      CREATE TABLE IF NOT EXISTS outbox_relay_checkpoints (
        partition_token         STRING(MAX)        NOT NULL,
        watermark               TIMESTAMP          NOT NULL,
        state                   STRING(32)         NOT NULL,
        parent_partition_tokens ARRAY<STRING(MAX)>,
        created_at              TIMESTAMP          NOT NULL OPTIONS (allow_commit_timestamp=true),
        updated_at              TIMESTAMP          NOT NULL OPTIONS (allow_commit_timestamp=true),
      ) PRIMARY KEY (partition_token)
    EOT
    ,
    <<-EOT
      CREATE CHANGE STREAM outbox_stream
        FOR outbox(shard_id, video_id, topic, payload, status, created_at)
        OPTIONS (
          value_capture_type = 'NEW_VALUES',
          retention_period   = '7d'
        )
    EOT
  ]
}
