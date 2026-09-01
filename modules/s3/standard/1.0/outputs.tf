locals {
  output_attributes = {
    bucket_name                 = aws_s3_bucket.main.id
    bucket_arn                  = aws_s3_bucket.main.arn
    region                      = aws_s3_bucket.main.region
    bucket_domain_name          = aws_s3_bucket.main.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name

    # The convenience IAM policies are count-gated (see create_iam_policies in main.tf), so these
    # must index the list and fall back to null rather than dereference a resource that may not
    # exist. one() returns the single element, or null when the count is 0.
    read_only_iam_policy_arn  = try(one(aws_iam_policy.read_only[*].arn), null)
    read_write_iam_policy_arn = try(one(aws_iam_policy.read_write[*].arn), null)
  }

  output_interfaces = {}
}
