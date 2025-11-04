locals {
  spec = lookup(var.instance, "spec", {})

  topic_name                 = lookup(local.spec, "topic_name", var.instance_name)
  message_retention_duration = lookup(local.spec, "message_retention_duration", "604800s")
  create_subscription        = lookup(local.spec, "create_subscription", true)
  subscription_ack_deadline  = lookup(local.spec, "subscription_ack_deadline", 10)

  gcp_project = var.inputs.cloud_account.attributes.project_id
  gcp_region  = var.inputs.cloud_account.attributes.region

  labels = merge(
    var.environment.cloud_tags,
    {
      instance_name = var.instance_name
      managed_by    = "facets"
    }
  )
}

# Create single Pub/Sub topic
resource "google_pubsub_topic" "topic" {
  name    = local.topic_name
  project = local.gcp_project

  message_retention_duration = local.message_retention_duration

  labels = local.labels
}

# Create subscription if requested
resource "google_pubsub_subscription" "subscription" {
  count = local.create_subscription ? 1 : 0

  name    = "${local.topic_name}-sub"
  topic   = google_pubsub_topic.topic.name
  project = local.gcp_project

  ack_deadline_seconds = local.subscription_ack_deadline

  labels = local.labels
}
