terraform {
  required_version = ">= 1.0"
}

# Reference (passthrough) flavour.
#
# This module deliberately declares NO resources and requires NO providers.
# It simply re-exposes the outputs of an existing Redis datastore (resolved
# into var.instance.spec.source via the `x-ui-output-type: @facets/redis`
# spec field) as a separate logical resource. See locals.tf / outputs.tf for
# the passthrough wiring.
