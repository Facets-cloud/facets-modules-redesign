# Attach IAM policies to the federated role
resource "aws_iam_role_policy_attachment" "this" {
  for_each   = local.policies
  role       = aws_iam_role.this.name
  policy_arn = each.value.arn
}
