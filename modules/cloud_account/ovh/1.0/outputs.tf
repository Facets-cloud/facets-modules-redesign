locals {
  output_attributes = {
    endpoint           = var.instance.spec.endpoint
    application_key    = sensitive(var.instance.spec.application_key)
    application_secret = sensitive(var.instance.spec.application_secret)
    consumer_key       = sensitive(var.instance.spec.consumer_key)
    project_id         = var.instance.spec.project_id
    secrets            = "[\"application_key\", \"application_secret\", \"consumer_key\"]"
  }
  output_interfaces = {
  }
}