locals {
  output_attributes = {
    bucket_name                 = aws_s3_bucket.main.id
    bucket_arn                  = aws_s3_bucket.main.arn
    region                      = aws_s3_bucket.main.region
    bucket_domain_name          = aws_s3_bucket.main.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    read_only_iam_policy_arn    = null
    read_write_iam_policy_arn   = null
  }
  output_interfaces = {}
}
