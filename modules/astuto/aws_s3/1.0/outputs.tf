# Define your outputs here

output "default_attributes" {
  value       = local.output_attributes
  description = "Attributes from the default output"
}

output "default_interfaces" {
  value       = local.output_interfaces
  description = "Interfaces from the default output"
}
