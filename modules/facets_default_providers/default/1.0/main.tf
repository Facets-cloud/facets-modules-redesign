# Facets Default Providers
# Foundational provider module. No Terraform resources are created here.
# The AWS provider exposed via facets.yaml outputs.default.providers.aws is
# consumed by legacy modules that bind aliases via iac-generator PR#76 dot
# convention (e.g., aws.aws3tooling in the consumer's input metadata).
