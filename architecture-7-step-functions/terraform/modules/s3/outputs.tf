# S3 Module Outputs

output "bucket_names" {
  description = "Names of the S3 buckets"
  value       = { for k, v in aws_s3_bucket.buckets : k => v.id }
}

output "bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = { for k, v in aws_s3_bucket.buckets : k => v.arn }
}
