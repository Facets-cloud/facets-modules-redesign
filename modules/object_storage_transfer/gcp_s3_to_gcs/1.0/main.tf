locals {
  spec = try(var.instance.spec, {})

  source = try(local.spec.source, {})
  target = try(local.spec.target, {})

  schedule = merge({
    status          = "ENABLED"
    mode            = "one_time"
    start_date      = "2026-08-27"
    end_date        = ""
    start_hour      = 0
    start_minute    = 0
    repeat_interval = "86400s"
  }, try(local.spec.schedule, {}))

  options = merge({
    overwrite_existing           = true
    delete_extra_in_target       = false
    include_prefixes             = []
    exclude_prefixes             = []
    min_age_seconds              = 0
    api_propagation_wait_seconds = 90
  }, try(local.spec.options, {}))

  naming = merge({
    transfer_job_description = ""
    aws_role_name            = ""
    aws_policy_name          = ""
  }, try(local.spec.naming, {}))

  source_bucket        = local.source.bucket
  source_prefix        = try(local.source.prefix, "")
  source_object_arn    = local.source_prefix == "" ? "arn:aws:s3:::${local.source_bucket}/*" : "arn:aws:s3:::${local.source_bucket}/${local.source_prefix}*"
  source_list_prefixes = local.source_prefix == "" ? [] : [local.source_prefix, "${local.source_prefix}*"]
  include_versions     = try(local.source.include_versions, false)
  source_kms_key_arns  = try(local.source.kms_key_arns, [])

  target_project_id = local.target.project_id
  target_bucket     = local.target.bucket
  target_prefix     = try(local.target.prefix, "")

  normalized_name = lower(replace(var.instance_name, "/[^a-zA-Z0-9_-]/", "-"))
  name_hash       = substr(sha1(var.instance_name), 0, 8)
  role_name       = local.naming.aws_role_name != "" ? local.naming.aws_role_name : substr("${local.normalized_name}-${local.name_hash}-sts", 0, 64)
  policy_name     = local.naming.aws_policy_name != "" ? local.naming.aws_policy_name : substr("${local.normalized_name}-${local.name_hash}-s3-read", 0, 128)
  description     = local.naming.transfer_job_description != "" ? local.naming.transfer_job_description : "Facets ${var.instance_name} S3 to GCS transfer"

  start_date_parts = split("-", local.schedule.start_date)
  end_date_parts   = local.schedule.end_date == "" ? local.start_date_parts : split("-", local.schedule.end_date)
  use_end_date     = local.schedule.mode == "one_time" || local.schedule.end_date != ""
  repeat_interval  = local.schedule.mode == "recurring" ? local.schedule.repeat_interval : null

  list_statement_base = {
    Effect   = "Allow"
    Action   = concat(["s3:ListBucket", "s3:GetBucketLocation"], local.include_versions ? ["s3:ListBucketVersions"] : [])
    Resource = "arn:aws:s3:::${local.source_bucket}"
  }

  list_statement_prefix_condition = {
    Condition = {
      StringLike = {
        "s3:prefix" = local.source_list_prefixes
      }
    }
  }

  object_actions = concat(["s3:GetObject"], local.include_versions ? ["s3:GetObjectVersion"] : [])

  kms_statements = length(local.source_kms_key_arns) == 0 ? [] : [
    {
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Resource = local.source_kms_key_arns
    }
  ]

  source_read_policy = local.source_prefix == "" ? jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      local.list_statement_base,
      {
        Effect   = "Allow"
        Action   = local.object_actions
        Resource = local.source_object_arn
      }
    ], local.kms_statements)
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      merge(local.list_statement_base, local.list_statement_prefix_condition),
      {
        Effect   = "Allow"
        Action   = local.object_actions
        Resource = local.source_object_arn
      }
    ], local.kms_statements)
  })

  tags = merge(
    try(var.environment.cloud_tags, {}),
    {
      Name      = local.role_name
      Facets    = "true"
      Resource  = var.instance_name
      ManagedBy = "facets"
      Purpose   = "s3-to-gcs-transfer"
    }
  )
}

data "google_client_config" "current" {}

data "google_project" "target" {
  project_id = local.target_project_id
}

resource "google_project_service" "storagetransfer" {
  project            = local.target_project_id
  service            = "storagetransfer.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storagetransfer_caller" {
  count              = data.google_client_config.current.project == local.target_project_id ? 0 : 1
  project            = data.google_client_config.current.project
  service            = "storagetransfer.googleapis.com"
  disable_on_destroy = false
}

resource "time_sleep" "wait_for_storagetransfer_api" {
  create_duration = "${local.options.api_propagation_wait_seconds}s"
  depends_on = [
    google_project_service.storagetransfer,
    google_project_service.storagetransfer_caller
  ]
}

data "google_storage_transfer_project_service_account" "this" {
  project = local.target_project_id
  depends_on = [
    google_project_service.storagetransfer,
    google_project_service.storagetransfer_caller,
    time_sleep.wait_for_storagetransfer_api
  ]
}

locals {
  transfer_service_account_email = "project-${data.google_project.target.number}@storage-transfer-service.iam.gserviceaccount.com"
}

resource "aws_iam_role" "this" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "accounts.google.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "accounts.google.com:sub" = data.google_storage_transfer_project_service_account.this.subject_id
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "source_read" {
  name        = local.policy_name
  description = "Read-only S3 access for ${var.instance_name} Storage Transfer Service job."

  policy = local.source_read_policy

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "source_read" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.source_read.arn
}

resource "google_storage_bucket_iam_member" "transfer_writer" {
  bucket = local.target_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.transfer_service_account_email}"
}

resource "google_storage_bucket_iam_member" "transfer_bucket_reader" {
  bucket = local.target_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${local.transfer_service_account_email}"
}

resource "google_storage_transfer_job" "this" {
  description = local.description
  project     = local.target_project_id
  status      = local.schedule.status

  transfer_spec {
    aws_s3_data_source {
      bucket_name = local.source_bucket
      path        = local.source_prefix
      role_arn    = aws_iam_role.this.arn
    }

    gcs_data_sink {
      bucket_name = local.target_bucket
      path        = local.target_prefix
    }

    object_conditions {
      include_prefixes                         = local.options.include_prefixes
      exclude_prefixes                         = local.options.exclude_prefixes
      min_time_elapsed_since_last_modification = local.options.min_age_seconds == 0 ? null : "${local.options.min_age_seconds}s"
    }

    transfer_options {
      overwrite_objects_already_existing_in_sink = local.options.overwrite_existing
      delete_objects_unique_in_sink              = local.options.delete_extra_in_target
      delete_objects_from_source_after_transfer  = false
    }
  }

  schedule {
    schedule_start_date {
      year  = tonumber(local.start_date_parts[0])
      month = tonumber(local.start_date_parts[1])
      day   = tonumber(local.start_date_parts[2])
    }

    dynamic "schedule_end_date" {
      for_each = local.use_end_date ? [1] : []
      content {
        year  = tonumber(local.end_date_parts[0])
        month = tonumber(local.end_date_parts[1])
        day   = tonumber(local.end_date_parts[2])
      }
    }

    start_time_of_day {
      hours   = local.schedule.start_hour
      minutes = local.schedule.start_minute
      seconds = 0
      nanos   = 0
    }

    repeat_interval = local.repeat_interval
  }

  depends_on = [
    aws_iam_role_policy_attachment.source_read,
    google_storage_bucket_iam_member.transfer_bucket_reader,
    google_storage_bucket_iam_member.transfer_writer
  ]
}
