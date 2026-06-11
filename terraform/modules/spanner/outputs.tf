output "change_stream_name" {
  description = "Name of the outbox Change Stream."
  value       = "outbox_stream"
}

output "checkpoint_table_name" {
  description = "Name of the relay checkpoint table."
  value       = "outbox_relay_checkpoints"
}
