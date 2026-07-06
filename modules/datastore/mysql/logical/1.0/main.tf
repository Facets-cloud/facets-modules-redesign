terraform {
  required_version = ">= 1.0"
}

# This is a reference / passthrough flavour. It provisions NO cloud resources and
# requires NO providers. It re-exposes the outputs of an existing MySQL datastore
# (var.instance.spec.source) so that consumers can wire to a logical database that
# shares a physical instance (e.g. staging database consolidation).
#
# All output wiring lives in outputs.tf.
