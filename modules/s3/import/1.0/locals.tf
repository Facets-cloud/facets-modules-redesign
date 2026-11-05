# Import-faithful S3 bucket: bucket name/tags plus the split sub-resources that live
# actually has (provider v6 splits versioning/SSE off the bucket) driven by the live
# spec (env override) so a plan against the live bucket is 0-change. versioning and
# SSE are each gated on presence in the spec so we only manage what live really has.
locals {
  spec = var.instance.spec
  b    = local.spec.bucket

  manage_versioning = lookup(local.b, "versioning_status", null) != null
  manage_sse        = lookup(local.b, "sse_algorithm", null) != null
}
