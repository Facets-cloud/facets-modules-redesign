locals {
  output_attributes = {
    publisher_role  = "roles/pubsub.publisher"
    subscriber_role = "roles/pubsub.subscriber"
    project_id      = local.gcp_project
  }

  output_interfaces = {
    default = {
      topic_name        = google_pubsub_topic.topic.name
      topic_id          = google_pubsub_topic.topic.id
      project_id        = local.gcp_project
      subscription_name = local.create_subscription ? google_pubsub_subscription.subscription[0].name : null
      subscription_id   = local.create_subscription ? google_pubsub_subscription.subscription[0].id : null
    }
  }
}
