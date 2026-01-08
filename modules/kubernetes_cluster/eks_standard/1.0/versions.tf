terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  # NO required_providers block - providers come from inputs via Facets
  # Provider versions are defined in the output type schemas
}
