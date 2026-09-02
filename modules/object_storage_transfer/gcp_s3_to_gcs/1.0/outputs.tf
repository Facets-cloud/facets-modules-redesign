locals {
  output_attributes = {
    transfer_job_name        = google_storage_transfer_job.this.name
    transfer_job_description = google_storage_transfer_job.this.description
    status                   = google_storage_transfer_job.this.status
    aws_role_arn             = aws_iam_role.this.arn
    aws_role_name            = aws_iam_role.this.name
    aws_policy_arn           = aws_iam_policy.source_read.arn
    source_bucket            = local.source_bucket
    source_prefix            = local.source_prefix
    target_project_id        = local.target_project_id
    target_bucket            = local.target_bucket
    target_prefix            = local.target_prefix
    mode                     = local.schedule.mode
    repeat_interval          = local.repeat_interval
  }

  output_interfaces = {
    transfer = {
      job_name          = google_storage_transfer_job.this.name
      source_bucket     = local.source_bucket
      source_prefix     = local.source_prefix
      target_bucket     = local.target_bucket
      target_prefix     = local.target_prefix
      target_project_id = local.target_project_id
    }
  }
}
