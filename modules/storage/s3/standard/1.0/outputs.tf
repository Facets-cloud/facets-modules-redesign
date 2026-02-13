locals {
  # Build outputs from created bucket resource
  output_attributes = {
    bucket_name                 = aws_s3_bucket.main.id
    bucket_arn                  = aws_s3_bucket.main.arn
    region                      = aws_s3_bucket.main.region
    bucket_domain_name          = aws_s3_bucket.main.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name

    # IAM policies for IRSA
    readonly_policy_arn   = aws_iam_policy.s3_readonly.arn
    readwrite_policy_arn  = aws_iam_policy.s3_readwrite.arn
    readonly_policy_name  = aws_iam_policy.s3_readonly.name
    readwrite_policy_name = aws_iam_policy.s3_readwrite.name
  }

  output_interfaces = {
    bucket = {
      name   = aws_s3_bucket.main.id
      arn    = aws_s3_bucket.main.arn
      region = aws_s3_bucket.main.region
    }
  }
}
