# Define your locals here

locals {
  advanced         = lookup(var.instance, "advanced", {})
  advanced_default = lookup(local.advanced, "s3", {})
  spec             = lookup(var.instance, "spec", {})

  # SSL enforcement
  enable_bucket_force_ssl = lookup(local.spec, "enable_bucket_force_ssl", false) ? jsonencode(
    {
      policy = {
        statement = [
          {
            Action    = "s3:*",
            Effect    = "Deny",
            Principal = "*",
            Condition = {
              Bool = {
                "aws:SecureTransport" = "false"
              }
            }
          }
        ]
      }
    }
  ) : jsonencode({})

  # Bucket policy
  aws_s3_bucket_policy = merge(
    lookup(local.advanced_default, "aws_s3_bucket_policy", lookup(local.spec, "aws_s3_bucket_policy", {})),
    jsondecode(local.enable_bucket_force_ssl)
  )

  bucket_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": ${local.statements}
}
EOF

  statements = jsonencode([for item in lookup(lookup(local.aws_s3_bucket_policy, "policy", {}), "statement", []) : merge(item, {
    Resource  = lookup(item, "Resource", [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"]),
    Condition = lookup(item, "Condition", {}),
    Action    = lookup(item, "Action", ""),
    Effect    = lookup(item, "Effect", ""),
    Principal = lookup(item, "Principal", ""),
    }
  )])

  # IAM policies for bucket access
  readonly_iam_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetLifecycleConfiguration",
                "s3:GetBucketTagging",
                "s3:GetInventoryConfiguration",
                "s3:GetObjectVersionTagging",
                "s3:ListBucketVersions",
                "s3:GetBucketLogging",
                "s3:ListBucket",
                "s3:GetAccelerateConfiguration",
                "s3:GetBucketPolicy",
                "s3:GetObjectVersionTorrent",
                "s3:GetObjectAcl",
                "s3:GetEncryptionConfiguration",
                "s3:GetBucketObjectLockConfiguration",
                "s3:GetBucketRequestPayment",
                "s3:GetObjectVersionAcl",
                "s3:GetObjectTagging",
                "s3:GetMetricsConfiguration",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetBucketPolicyStatus",
                "s3:ListBucketMultipartUploads",
                "s3:GetObjectRetention",
                "s3:GetBucketWebsite",
                "s3:GetBucketVersioning",
                "s3:GetBucketAcl",
                "s3:GetObjectLegalHold",
                "s3:GetBucketNotification",
                "s3:GetReplicationConfiguration",
                "s3:ListMultipartUploadParts",
                "s3:GetObject",
                "s3:GetObjectTorrent",
                "s3:GetBucketCORS",
                "s3:GetAnalyticsConfiguration",
                "s3:GetObjectVersionForReplication",
                "s3:GetBucketLocation",
                "s3:GetObjectVersion",
                "s3:RestoreObject",
                "s3:ListObjects"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
            ]
        }
    ]
}
EOF

  readwrite_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:DeleteObjectTagging",
                "s3:DeleteObjectVersion",
                "s3:DeleteObjectVersionTagging",
                "s3:GetAccelerateConfiguration",
                "s3:GetAnalyticsConfiguration",
                "s3:GetBucketAcl",
                "s3:GetBucketCORS",
                "s3:GetBucketLocation",
                "s3:GetBucketLogging",
                "s3:GetBucketNotification",
                "s3:GetBucketObjectLockConfiguration",
                "s3:GetBucketPolicy",
                "s3:GetBucketPolicyStatus",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetBucketRequestPayment",
                "s3:GetBucketTagging",
                "s3:GetBucketVersioning",
                "s3:GetBucketWebsite",
                "s3:GetEncryptionConfiguration",
                "s3:GetInventoryConfiguration",
                "s3:GetLifecycleConfiguration",
                "s3:GetMetricsConfiguration",
                "s3:GetObject",
                "s3:GetObjectAcl",
                "s3:GetObjectLegalHold",
                "s3:GetObjectRetention",
                "s3:GetObjectTagging",
                "s3:GetObjectTorrent",
                "s3:GetObjectVersion",
                "s3:GetObjectVersionAcl",
                "s3:GetObjectVersionForReplication",
                "s3:GetObjectVersionTagging",
                "s3:GetObjectVersionTorrent",
                "s3:GetReplicationConfiguration",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucketVersions",
                "s3:ListMultipartUploadParts",
                "s3:PutAccelerateConfiguration",
                "s3:PutAnalyticsConfiguration",
                "s3:PutBucketAcl",
                "s3:PutBucketCORS",
                "s3:PutBucketLogging",
                "s3:PutBucketNotification",
                "s3:PutBucketObjectLockConfiguration",
                "s3:PutBucketPolicy",
                "s3:PutBucketPublicAccessBlock",
                "s3:PutBucketRequestPayment",
                "s3:PutBucketTagging",
                "s3:PutBucketVersioning",
                "s3:PutBucketWebsite",
                "s3:PutEncryptionConfiguration",
                "s3:PutInventoryConfiguration",
                "s3:PutLifecycleConfiguration",
                "s3:PutMetricsConfiguration",
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:PutObjectLegalHold",
                "s3:PutObjectRetention",
                "s3:PutObjectTagging",
                "s3:PutObjectVersionAcl",
                "s3:PutObjectVersionTagging",
                "s3:PutReplicationConfiguration",
                "s3:RestoreObject",
                "s3:ListObjects"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
            ]
        }
    ]
}
EOF

  # ACL configuration
  acl                       = lookup(local.advanced_default, "acl", {})
  create_replication_role   = lookup(lookup(local.advanced_default, "replication_configuration", {}), "create_replication_role", false)
  create_replication_policy = lookup(lookup(local.advanced_default, "replication_configuration", {}), "create_replication_policy", false)
  object_ownership          = lookup(local.acl, "object_ownership", "BucketOwnerEnforced")
  block_public_acls         = lookup(local.acl, "block_public_acls", false)
  block_public_policy       = lookup(local.acl, "block_public_policy", false)
  ignore_public_acls        = lookup(local.acl, "ignore_public_acls", false)
  restrict_public_buckets   = lookup(local.acl, "restrict_public_buckets", false)
}

# Output attributes and interfaces
locals {
  output_attributes = {
    bucket_name                 = aws_s3_bucket.bucket.bucket
    bucket_arn                  = aws_s3_bucket.bucket.arn
    read_only_iam_policy_arn    = aws_iam_policy.readonly.arn
    read_write_iam_policy_arn   = aws_iam_policy.readwrite.arn
    bucket_region               = aws_s3_bucket.bucket.region
    bucket_regional_domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    website_endpoint            = aws_s3_bucket.bucket.website_endpoint
  }

  output_interfaces = {}
}
