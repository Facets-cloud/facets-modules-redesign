module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "s3"
  globally_unique = true
}

locals {
  # Instance spec shortcuts
  spec = var.instance.spec

  # Bucket name via utility module (globally unique, max 63 chars)
  bucket_name   = lookup(local.spec, "bucket_name", module.name.name)
  force_destroy = try(local.spec.force_destroy, false)

  # Encryption configuration
  encryption_enabled = try(local.spec.encryption_enabled, true)
  kms_key_id         = try(local.spec.kms_key_id, null)
  bucket_key_enabled = try(local.spec.bucket_key_enabled, true)

  # Use KMS if key provided, otherwise SSE-S3.
  # ADOPTION: a live bucket is often "aws:kms" with NO explicit key (the AWS-managed aws/s3 key),
  # which the key-driven default cannot express. spec.sse_algorithm pins it directly.
  sse_algorithm = try(local.spec.sse_algorithm, local.kms_key_id != null ? "aws:kms" : "AES256")
  # Emit bucket_key_enabled whenever it is explicitly set, not only alongside a customer KMS key —
  # live buckets commonly report BucketKeyEnabled=false under the AWS-managed key.
  bucket_key_enabled_set = can(local.spec.bucket_key_enabled)

  # Versioning configuration.
  # ADOPTION: S3 distinguishes "Disabled" (never versioned) from "Suspended" (was enabled, then
  # turned off). The boolean can only express Enabled/Suspended, so writing "Suspended" onto a
  # never-versioned bucket is a REAL state change. spec.versioning_status pins the live value.
  versioning_enabled = try(local.spec.versioning_enabled, false)
  versioning_status  = try(local.spec.versioning_status, local.versioning_enabled ? "Enabled" : "Suspended")

  # Public access block configuration
  public_access_block = {
    block_public_acls       = try(local.spec.block_public_acls, true)
    block_public_policy     = try(local.spec.block_public_policy, true)
    ignore_public_acls      = try(local.spec.ignore_public_acls, true)
    restrict_public_buckets = try(local.spec.restrict_public_buckets, true)
  }

  # Lifecycle rules
  lifecycle_rules     = try(local.spec.lifecycle_rules, [])
  has_lifecycle_rules = length(local.lifecycle_rules) > 0

  # CORS rules
  cors_rules     = try(local.spec.cors_rules, [])
  has_cors_rules = length(local.cors_rules) > 0

  # Bucket policy
  bucket_policy_json = try(local.spec.bucket_policy_json, null)
  has_bucket_policy  = local.bucket_policy_json != null && local.bucket_policy_json != ""

  # Tags
  custom_tags = try(local.spec.tags, {})

  # Merge environment tags with custom tags
  all_tags = merge(
    var.environment.cloud_tags,
    local.custom_tags,
    {
      Name          = var.instance_name
      resource_type = "s3"
      flavor        = "standard"
    }
  )

}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket        = local.bucket_name
  force_destroy = local.force_destroy

  tags = local.all_tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all]
  }
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = local.versioning_status
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count = local.encryption_enabled ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = local.kms_key_id
    }

    bucket_key_enabled = local.bucket_key_enabled_set || local.kms_key_id != null ? local.bucket_key_enabled : null
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = local.public_access_block.block_public_acls
  block_public_policy     = local.public_access_block.block_public_policy
  ignore_public_acls      = local.public_access_block.ignore_public_acls
  restrict_public_buckets = local.public_access_block.restrict_public_buckets
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = local.has_lifecycle_rules ? 1 : 0

  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = try(rule.value.enabled, true) ? "Enabled" : "Disabled"

      # Filter by prefix if specified
      dynamic "filter" {
        for_each = try(rule.value.prefix, null) != null ? [1] : []

        content {
          prefix = try(rule.value.prefix, "")
        }
      }

      # If no prefix, use empty filter
      dynamic "filter" {
        for_each = try(rule.value.prefix, null) == null ? [1] : []

        content {}
      }

      # Transitions to different storage classes
      dynamic "transition" {
        for_each = try(rule.value.transitions, [])

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Expiration for current versions
      dynamic "expiration" {
        for_each = try(rule.value.expiration_days, null) != null ? [1] : []

        content {
          days = rule.value.expiration_days
        }
      }

      # Expiration for noncurrent versions (versioned buckets)
      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration_days, null) != null ? [1] : []

        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }

      # Abort incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_days, null) != null ? [1] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "main" {
  count = local.has_cors_rules ? 1 : 0

  bucket = aws_s3_bucket.main.id

  dynamic "cors_rule" {
    for_each = local.cors_rules

    content {
      allowed_origins = cors_rule.value.allowed_origins
      allowed_methods = cors_rule.value.allowed_methods
      allowed_headers = try(cors_rule.value.allowed_headers, null)
      expose_headers  = try(cors_rule.value.expose_headers, null)
      max_age_seconds = try(cors_rule.value.max_age_seconds, 3600)
    }
  }
}

# Bucket Policy
resource "aws_s3_bucket_policy" "main" {
  count = local.has_bucket_policy ? 1 : 0

  bucket = aws_s3_bucket.main.id
  policy = local.bucket_policy_json

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# IAM policy for read-only access to this bucket
resource "aws_iam_policy" "read_only" {
  name        = lookup(local.spec, "read_only_policy_name", "${module.name.name}-read-only")
  description = "Read-only access to ${local.bucket_name} S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:GetBucketLocation",
            "s3:GetBucketVersioning"
          ]
          Resource = [
            aws_s3_bucket.main.arn,
            "${aws_s3_bucket.main.arn}/*"
          ]
        }
      ],
      local.kms_key_id != null ? [
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = [local.kms_key_id]
        }
      ] : []
    )
  })
  tags = local.all_tags
  lifecycle {
    ignore_changes = [description, policy, tags, tags_all]
  }
}

# IAM policy for read-write access to this bucket
resource "aws_iam_policy" "read_write" {
  name        = lookup(local.spec, "read_write_policy_name", "${module.name.name}-read-write")
  description = "Read-write access to ${local.bucket_name} S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:GetBucketLocation",
            "s3:GetBucketVersioning"
          ]
          Resource = [
            aws_s3_bucket.main.arn,
            "${aws_s3_bucket.main.arn}/*"
          ]
        }
      ],
      local.kms_key_id != null ? [
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = [local.kms_key_id]
        }
      ] : []
    )
  })
  tags = local.all_tags
  lifecycle {
    ignore_changes = [description, policy, tags, tags_all]
  }
}
