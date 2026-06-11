variable "project_id" {
  type        = string
  description = "The GCP project ID."
  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "spanner_instance" {
  type        = string
  description = "Name of the existing Spanner instance."
}

variable "spanner_database" {
  type        = string
  description = "Name of the existing Spanner database."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., development, staging, production)."
}
