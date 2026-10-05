# S3 bucket (imported; name/tags from live). Live was built with an old AWS provider
# that kept versioning/SSE inline on the bucket; under provider v6 those are separate
# resources, declared below only when the live bucket actually has them.
resource "aws_s3_bucket" "main" {
  bucket        = local.b.name
  force_destroy = lookup(local.b, "force_destroy", false)
  tags          = lookup(local.b, "tags", {})

  # CP-managed tags (facetsclusterid/facetscontrolplane/cluster) are injected by the control plane,
  # not owned here — adopt live tags as-is rather than hardcoding them in spec.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all]
  }
}

resource "aws_s3_bucket_versioning" "main" {
  count  = local.manage_versioning ? 1 : 0
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = local.b.versioning_status
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count  = local.manage_sse ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.b.sse_algorithm
      kms_master_key_id = lookup(local.b, "kms_master_key_id", null)
    }
    bucket_key_enabled = lookup(local.b, "bucket_key_enabled", null)
  }
}
