locals {
  secrets                        = [for key, value in merge(module.name_dockerhub, module.name) : value.name]
  output_registry_secrets_list   = [for value in local.secrets : { name = value }]
  output_registry_secret_objects = { for value in local.secrets : value => [{ name = value }] }
  output_interfaces              = {}
  output_attributes = {
    registry_secrets_list   = local.output_registry_secrets_list
    registry_secret_objects = local.output_registry_secret_objects
  }
}
