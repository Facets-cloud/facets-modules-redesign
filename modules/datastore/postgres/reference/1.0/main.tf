# PostgreSQL Reference flavour
#
# This flavour creates NO cloud resources and declares NO providers.
# It is a pure passthrough: it re-exposes the connection outputs of an
# existing postgres datastore (selected via spec.source), optionally
# re-targeting the connection string at a different logical database.
#
# Use case: staging DB consolidation, where a logical database points at a
# shared physical instance. The source datastore is selected per-environment
# (override-able), so the same blueprint resource can fan out to different
# shared instances across environments.

terraform {
  required_version = ">= 1.0"
}

# Intentionally no resources.
