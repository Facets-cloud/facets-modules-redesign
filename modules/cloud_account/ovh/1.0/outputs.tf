locals {
  output_attributes = {
    endpoint           = var.instance.spec.endpoint
    application_key    = var.instance.spec.application_key
    application_secret = var.instance.spec.application_secret
    consumer_key       = var.instance.spec.consumer_key
    project_id         = var.instance.spec.project_id
    secrets            = "[\"application_key\", \"application_secret\", \"consumer_key\"]"
  }
  output_interfaces = {
  }
}