# S3 Module Outputs

output "staging_bucket_name" {
  description = "Name of the staging S3 bucket"
  value       = aws_s3_bucket.staging.bucket
}

output "staging_bucket_arn" {
  description = "ARN of the staging S3 bucket"
  value       = aws_s3_bucket.staging.arn
}

output "staging_bucket_domain_name" {
  description = "Domain name of the staging S3 bucket"
  value       = aws_s3_bucket.staging.bucket_domain_name
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed.bucket
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "processed_bucket_domain_name" {
  description = "Domain name of the processed S3 bucket"
  value       = aws_s3_bucket.processed.bucket_domain_name
}

output "logs_bucket_name" {
  description = "Name of the logs S3 bucket"
  value       = aws_s3_bucket.logs.bucket
}

output "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  value       = aws_s3_bucket.logs.arn
}

output "logs_bucket_domain_name" {
  description = "Domain name of the logs S3 bucket"
  value       = aws_s3_bucket.logs.bucket_domain_name
}
