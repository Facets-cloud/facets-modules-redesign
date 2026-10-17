locals {
  # IAM stays owned by saas-cp until handoff (project unique_name differs, names cannot match live)
  manage_iam = lookup(lookup(var.instance, "spec", {}), "manage_iam", false)
  sa_name    = "${var.environment.unique_name}-${lower(var.instance_name)}"

  spec             = lookup(var.instance, "spec", {})
  advanced         = lookup(var.instance, "advanced", {})
  loki_flavor      = lookup(local.advanced, "loki_s3", {})
  loki_helm        = lookup(local.loki_flavor, "loki", {})
  loki             = lookup(local.loki_helm, "values", {})
  promtail_helm    = lookup(local.loki_flavor, "promtail", {})
  loki_canary_helm = lookup(local.loki_flavor, "loki_canary", {})
  bucket_name      = lookup(local.loki_flavor, "bucket_name", var.inputs.s3_details.attributes.bucket_name)
  loki_namespace   = lookup(local.loki_helm, "namespace", "facets")
  query_timeout    = lookup(local.loki_flavor, "query_timeout", 60)
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
                "s3:RestoreObject"
            ],
            "Resource": [
                "arn:aws:s3:::${local.bucket_name}",
                "arn:aws:s3:::${local.bucket_name}/*"
            ]
        }
    ]
}
EOF

  log_collector_loki = {
    loki = merge(
      local.loki_helm,
      {
        values = merge(
          local.loki,
          {
            loki = {
              structuredConfig = merge(
                lookup(lookup(local.loki, "loki", {}), "structuredConfig", {}),
                {
                  storage_config = merge(
                    {
                      aws = {
                        s3               = "s3://${data.aws_region.current.name}/${local.bucket_name}"
                        s3forcepathstyle = false
                        http_config = {
                          response_header_timeout = "300s"
                        }
                      }
                      boltdb_shipper = {
                        shared_store = "s3"
                        cache_ttl    = "48h"
                      }
                    },
                    lookup(lookup(lookup(local.loki, "loki", {}), "structuredConfig", {}), "storage_config", {}),
                  )
                }
              )
            },
            serviceAccount = {
              create = true
              name   = local.sa_name
              annotations = {
                "eks.amazonaws.com/role-arn" = try(module.irsa[0].iam_role_arn, "")
              }
            }
          }
        )
      }
    )
  }

  log_collector_promtail = {
    promtail = merge(
      local.promtail_helm,
      {
        values = lookup(local.promtail_helm, "values", {})
      }
    )
  }
  log_collector_loki_canary = {
    loki_canary = merge(
      local.loki_canary_helm,
      {
        enable_loki_canary = lookup(local.loki_canary_helm, "enable_loki_canary", false)
        values             = lookup(local.loki_canary_helm, "values", {})
      }
    )
  }

  log_collector = {
    spec = local.spec
    advanced = {
      loki = merge(
        local.log_collector_loki,
        local.log_collector_promtail,
        local.log_collector_loki_canary,
        {
          query_timeout  = local.query_timeout
          derived_fields = lookup(local.loki_flavor, "derived_fields", {})
        }
      )
    }
  }
}
