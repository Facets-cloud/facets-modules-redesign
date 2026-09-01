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

  # Bucket NAME. The bucket name is a ForceNew attribute, so an explicit spec.name always wins over
  # the generated one — emitting a different name would plan a replace, i.e. data loss.
  # module.name.name is the greenfield fallback for a brand-new bucket.
  # Explicit conditional rather than coalesce(): coalesce treats "" as absent in some positions and
  # errors when every argument is null/empty, which is exactly how the policy line below broke. An
  # explicit test says what it means and cannot surprise.
  # Identity lives in spec.imports, which is overrides-only: production pins the live object
  # there, a new environment has no override and builds its own. spec.name is still honoured as a
  # fallback so publishing this schema cannot orphan a resource whose override has not migrated —
  # the name is ForceNew, and losing it emits a generated one and plans destroy+create.
  imports     = lookup(local.spec, "imports", {})
  adopt       = lookup(local.imports, "import_existing", false)
  import_name = lookup(local.imports, "bucket_name", null)
  legacy_name = lookup(local.spec, "name", null)
  name_override = (local.import_name != null && local.import_name != "" ? local.import_name
  : (local.legacy_name != null && local.legacy_name != "" ? local.legacy_name : null))
  bucket_name = (local.name_override == null || local.name_override == ""
    ? module.name.name
  : local.name_override)

  force_destroy = lookup(local.spec, "force_destroy", false)

  # Encryption configuration
  encryption_enabled = lookup(local.spec, "encryption_enabled", true)
  kms_key_id         = lookup(local.spec, "kms_key_id", null)

  # bucket_key_enabled is INDEPENDENT of KMS. S3 reports BucketKeyEnabled on SSE-S3 buckets too,
  # so tying it to kms_key_id (as 1.0 did) emits null against a live `true` and drifts.
  bucket_key_enabled = lookup(local.spec, "bucket_key_enabled", true)

  # Use KMS if key provided, otherwise SSE-S3
  sse_algorithm = local.kms_key_id != null ? "aws:kms" : "AES256"

  # Versioning — three live states, not two. A bucket that has NEVER had versioning has no
  # versioning configuration at all; 1.0 unconditionally declared one with status "Suspended",
  # which on such a bucket is a CREATE, not an adoption. manage_versioning gates the resource so
  # "not configured" is expressible.
  manage_versioning  = lookup(local.spec, "manage_versioning", true)
  versioning_enabled = lookup(local.spec, "versioning_enabled", false)

  # Public access block — same reasoning: a bucket may have none.
  manage_public_access_block = lookup(local.spec, "manage_public_access_block", true)

  # The two convenience IAM policies are a greenfield nicety. Creating them during an adoption
  # would be a real IAM write against the customer's account, which a read-only posture forbids
  # and a zero-change plan must not contain.
  create_iam_policies = lookup(local.spec, "create_iam_policies", true)

  # Public access block configuration
  public_access_block = {
    block_public_acls       = try(local.spec.block_public_acls, true)
    block_public_policy     = try(local.spec.block_public_policy, true)
    ignore_public_acls      = try(local.spec.ignore_public_acls, true)
    restrict_public_buckets = try(local.spec.restrict_public_buckets, true)
  }

  # Lifecycle rules
  # maps, not lists: the Facets UI does not support an array of objects, and a map keyed by rule id
  # also makes the identity explicit instead of positional
  lifecycle_rules     = lookup(local.spec, "lifecycle_rules", {})
  has_lifecycle_rules = length(local.lifecycle_rules) > 0

  # `rule` is an ORDERED list in terraform state, but the spec is a map (the UI cannot do an array of
  # objects) and a map iterates lexicographically. Without an explicit order every rule of a
  # multi-rule bucket shows a diff purely from resequencing. `order` carries the live index; the
  # zero-padded sort key keeps 10 after 9.
  lc_ordered = [
    for e in sort([
      for k, v in local.lifecycle_rules : format("%05d~%s", lookup(v, "order", 9999), k)
    ]) : merge(local.lifecycle_rules[split("~", e)[1]], { _key = split("~", e)[1] })
  ]

  # Bucket-level lifecycle setting, NOT part of any rule. The AWS provider defaults it to
  # "all_storage_classes_128K", but buckets whose lifecycle predates that default read back
  # "varies_by_storage_class" — so leaving it unmodelled drifts on adoption
  # (`varies_by_storage_class -> all_storage_classes_128K`, caught on analytics-ingestion-1).
  # null lets the provider keep its own default for a new bucket.
  transition_default_minimum_object_size = lookup(local.spec, "transition_default_minimum_object_size", null)

  # CORS rules
  cors_rules     = lookup(local.spec, "cors_rules", {})
  has_cors_rules = length(local.cors_rules) > 0

  # ── Bucket policy ────────────────────────────────────────────────────────────────────────
  # Supplied as a document via bucket_policy_json. Id and Version live INSIDE that JSON, where they
  # belong. There is no module-generated variant.
  #
  # Placeholders make even the raw document portable. Two kinds, for two different reasons:
  #
  #   __BUCKET_ARN__ / __BUCKET_NAME__   SELF references. A Facets expression cannot resolve these —
  #                                      a resource referencing its own output is circular — so they
  #                                      are substituted HERE, where aws_s3_bucket.main is in scope.
  #   cross-resource values              Use a real Facets reference in the spec instead, e.g.
  #                                      ${cloud_account.aws.out.attributes.account_id}. Those are
  #                                      resolved by the platform before this module ever runs, so the
  #                                      module needs no knowledge of them.
  raw_policy = lookup(local.spec, "bucket_policy_json", null)
  raw_policy_resolved = (local.raw_policy == null || local.raw_policy == ""
    ? null
    : replace(
      replace(local.raw_policy, "__BUCKET_ARN__", aws_s3_bucket.main.arn),
      "__BUCKET_NAME__", aws_s3_bucket.main.id
  ))

  # The policy is always the supplied document. There is no module-generated variant: a flag that
  # silently owns a live security policy hides what is actually deployed, and __BUCKET_ARN__ makes the
  # literal just as portable. 11 buckets in this estate have no policy at all, which is why the empty
  # string is a legitimate outcome.
  bucket_policy_json = local.raw_policy_resolved != null ? local.raw_policy_resolved : ""
  # count must be known at plan; the substituted policy references the bucket ARN
  # (unknown for a NEW bucket), so gate on the raw INPUT, which is always known.
  has_bucket_policy = local.raw_policy != null && local.raw_policy != ""

  # ── Access logging + object ownership ────────────────────────────────────────────────────
  # Live on this estate but unmodelled until now: Facets could ADOPT them cleanly (terraform does not
  # diff what it does not declare) yet could not REPRODUCE them in a new environment — and a staging
  # env that replicates production is the goal. Both count-gated, so a bucket without them stays so.
  logging        = lookup(local.spec, "logging", {})
  manage_logging = contains(keys(local.logging), "target_bucket")

  # A bucket that logs to ITSELF cannot use a Facets reference to its own output — the validator
  # rejects it as a cycle. It writes __BUCKET_NAME__ instead, substituted here, same as the policy.
  log_target = local.manage_logging ? replace(
    local.logging.target_bucket, "__BUCKET_NAME__", aws_s3_bucket.main.id
  ) : null
  object_ownership = lookup(local.spec, "object_ownership", null)

  # Tags. On a greenfield bucket the environment's cloud_tags plus the Facets identity tags are
  # wanted. On an ADOPTED bucket they are an in-place `~ tags` change to someone else's resource —
  # and a bucket with no tags at all is common. inject_env_tags=false makes spec.tags the complete,
  # authoritative tag set, so `tags = {}` faithfully means "live has none".
  custom_tags     = lookup(local.spec, "tags", {})
  inject_env_tags = lookup(local.spec, "inject_env_tags", true)

  facets_tags = {
    Name          = var.instance_name
    resource_type = "s3"
    flavor        = "standard"
  }

  all_tags = local.inject_env_tags ? merge(
    var.environment.cloud_tags,
    local.custom_tags,
    local.facets_tags,
  ) : local.custom_tags
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket        = local.bucket_name
  force_destroy = local.force_destroy

  tags = local.all_tags

  lifecycle {
    prevent_destroy = true
  }
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  count = local.manage_versioning ? 1 : 0

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

    # NOT gated on kms_key_id. S3 reports BucketKeyEnabled on SSE-S3 (AES256) buckets as well, so
    # emitting null here against a live `true` is a real in-place change — which is exactly what the
    # 0-change gate caught on blacklisted-ip (`bucket_key_enabled = true -> null`).
    bucket_key_enabled = local.bucket_key_enabled
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "main" {
  count = local.manage_public_access_block ? 1 : 0

  bucket = aws_s3_bucket.main.id

  block_public_acls       = local.public_access_block.block_public_acls
  block_public_policy     = local.public_access_block.block_public_policy
  ignore_public_acls      = local.public_access_block.ignore_public_acls
  restrict_public_buckets = local.public_access_block.restrict_public_buckets
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = local.has_lifecycle_rules ? 1 : 0

  bucket                                 = aws_s3_bucket.main.id
  transition_default_minimum_object_size = local.transition_default_minimum_object_size

  dynamic "rule" {
    for_each = local.lc_ordered

    content {
      id     = rule.value._key
      status = lookup(rule.value, "enabled", true) ? "Enabled" : "Disabled"

      # Filter by prefix if specified
      dynamic "filter" {
        for_each = lookup(rule.value, "prefix", null) != null ? [1] : []

        content {
          prefix = lookup(rule.value, "prefix", "")
        }
      }

      # A prefix-less rule: emit an EMPTY filter only when the rule asks for it.
      #
      # A live rule with `Filter: {}` (or no Filter at all) imports into state as having NO filter
      # block, so unconditionally emitting `filter {}` shows up as `+ filter {}` on every such rule
      # — 13 buckets in this estate. But a brand-new rule generally does need a filter, so this
      # cannot simply be deleted: emit_filter defaults to TRUE, preserving greenfield behaviour,
      # and adoption sets it false for the rules whose live filter is empty.
      dynamic "filter" {
        for_each = (lookup(rule.value, "prefix", null) == null
        && lookup(rule.value, "emit_filter", true)) ? [1] : []

        content {}
      }

      # Transitions to different storage classes
      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", {})

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Expiration for current versions.
      # Two mutually-exclusive live forms: an age in days, or the delete-marker cleanup form
      # (`Expiration: {ExpiredObjectDeleteMarker: true}` with no Days). Emit the block if EITHER is
      # present, and pass both through so whichever is unset stays null.
      dynamic "expiration" {
        for_each = (lookup(rule.value, "expiration_days", null) != null
        || lookup(rule.value, "expired_object_delete_marker", null) != null) ? [1] : []

        content {
          days                         = lookup(rule.value, "expiration_days", null)
          expired_object_delete_marker = lookup(rule.value, "expired_object_delete_marker", null)
        }
      }

      # Expiration for noncurrent versions (versioned buckets)
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration_days", null) != null ? [1] : []

        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }

      # Transitions for NONCURRENT versions. Distinct from `transition` (current versions) and from
      # `noncurrent_version_expiration` (deletion) — 1.2 modelled neither, so a live
      # NoncurrentVersionTransitions rule planned as a removal.
      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_version_transitions", {})

        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      # Abort incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_multipart_days", null) != null ? [1] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main] # count-gated; empty list when unmanaged
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

  depends_on = [aws_s3_bucket_public_access_block.main] # count-gated; empty list when unmanaged
}

# Access Logging
resource "aws_s3_bucket_logging" "main" {
  count = local.manage_logging ? 1 : 0

  bucket        = aws_s3_bucket.main.id
  target_bucket = local.log_target
  target_prefix = lookup(local.logging, "target_prefix", "")

  # S3 can partition delivered log keys. Unmodelled, this reads as a removal on the 3 buckets that
  # set it.
  dynamic "target_object_key_format" {
    for_each = lookup(local.logging, "key_format", null) != null ? [local.logging.key_format] : []

    content {
      dynamic "partitioned_prefix" {
        for_each = lookup(target_object_key_format.value, "partition_date_source", null) != null ? [1] : []
        content {
          partition_date_source = target_object_key_format.value.partition_date_source
        }
      }
      dynamic "simple_prefix" {
        for_each = lookup(target_object_key_format.value, "simple", false) ? [1] : []
        content {}
      }
    }
  }
}

# Object Ownership (ACL posture). BucketOwnerEnforced disables ACLs entirely.
resource "aws_s3_bucket_ownership_controls" "main" {
  count = local.object_ownership != null ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = local.object_ownership
  }
}

# IAM policy for read-only access to this bucket
resource "aws_iam_policy" "read_only" {
  count = local.create_iam_policies ? 1 : 0

  name        = "${module.name.name}-read-only"
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
  count = local.create_iam_policies ? 1 : 0

  name        = "${module.name.name}-read-write"
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
