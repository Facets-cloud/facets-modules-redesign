# Customer-managed IAM policy (imported; attributes from live). The provider
# normalizes the policy JSON, so a semantic match to live is enough for 0-change.
resource "aws_iam_policy" "main" {
  name        = local.p.name
  path        = lookup(local.p, "path", "/")
  description = lookup(local.p, "description", null)
  policy      = local.p.policy
  tags        = lookup(local.p, "tags", {})

  # CP-managed tags are injected by the control plane, not owned here — adopt live tags as-is.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}
