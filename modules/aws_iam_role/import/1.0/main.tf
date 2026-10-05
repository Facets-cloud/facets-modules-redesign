# IAM role (imported; attributes from live). assume_role_policy JSON is normalized
# by the provider, so a semantic match to live is enough for 0-change.
resource "aws_iam_role" "main" {
  name                 = local.r.name
  assume_role_policy   = local.r.assume_role_policy
  max_session_duration = lookup(local.r, "max_session_duration", 3600)
  path                 = lookup(local.r, "path", "/")
  permissions_boundary = lookup(local.r, "permissions_boundary", null)
  tags                 = lookup(local.r, "tags", {})

  # CP-managed tags are injected by the control plane, not owned here — adopt live tags as-is.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Managed-policy attachments (customer + AWS-managed). The policies themselves are
# referenced by ARN as literals; only the attachment is managed here.
resource "aws_iam_role_policy_attachment" "main" {
  for_each   = local.policy_arns
  role       = aws_iam_role.main.name
  policy_arn = each.value
}
