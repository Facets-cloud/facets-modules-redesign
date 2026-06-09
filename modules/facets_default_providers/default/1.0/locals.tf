locals {
  # No attributes exposed — consumers don't read anything from this module's output.
  # The aws3tooling provider configuration is injected by the platform via facets.yaml
  # outputs.default.providers, and the provider picks up credentials/region from pod
  # environment variables (AWS_REGION, AWS_ACCESS_KEY_ID, etc.) at terraform init time.
  output_attributes = {}
  output_interfaces = {}
}
