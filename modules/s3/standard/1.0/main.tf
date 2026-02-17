locals {
  # Instance spec shortcuts
  spec = var.instance.spec

  # Bucket configuration - auto-generate from environment and instance name
  # S3 bucket names: 3-63 characters, lowercase, no underscores
  bucket_name   = "${var.instance_name}-${var.environment.unique_name}"
  force_destroy = try(local.spec.force_destroy, false)

  # Encryption configuration
  encryption_enabled = try(local.spec.encryption_enabled, true)
  kms_key_id         = try(local.spec.kms_key_id, null)
  bucket_key_enabled = try(local.spec.bucket_key_enabled, true)

  # Use KMS if key provided, otherwise SSE-S3
  sse_algorithm = local.kms_key_id != null ? "aws:kms" : "AES256"

  # Versioning configuration
  versioning_enabled = try(local.spec.versioning_enabled, false)

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
      resource_type = "s3_bucket"
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
    # Prevent accidental deletion in production
    prevent_destroy = false
  }
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = local.versioning_enabled ? "Enabled" : "Suspended"
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

    bucket_key_enabled = local.kms_key_id != null ? local.bucket_key_enabled : null
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
  name        = "${var.instance_name}-${var.environment.unique_name}-read-only"
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
}

# IAM policy for read-write access to this bucket
resource "aws_iam_policy" "read_write" {
  name        = "${var.instance_name}-${var.environment.unique_name}-read-write"
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
}
