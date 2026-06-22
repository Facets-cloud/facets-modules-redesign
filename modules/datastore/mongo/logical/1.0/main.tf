# main.tf - Reference flavour for mongo.
#
# This flavour creates NO cloud resources and requires NO provider. It is a pure
# passthrough that re-exposes the outputs of an already-provisioned mongo /
# DocumentDB datastore selected via spec.source. See locals.tf for the contract
# re-emission and outputs.tf for the exposed interfaces.

terraform {
  required_version = ">= 1.0"
}
