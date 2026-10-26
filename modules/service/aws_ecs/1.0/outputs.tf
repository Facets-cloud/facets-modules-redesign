locals {
  output_attributes = {
    namespace           = var.instance.spec.cluster_arn
    resource_name       = var.instance.spec.service_name
    resource_type       = "ecs"
    selector_labels     = "ecs_service=${var.instance.spec.service_name}"
    service_account_arn = var.instance.spec.task_role_arn
    service_name        = var.instance.spec.service_name
  }
  output_interfaces = {}
}
