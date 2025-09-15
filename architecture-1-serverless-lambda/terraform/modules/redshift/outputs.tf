# Redshift Module Outputs

output "cluster_id" {
  description = "Redshift cluster identifier"
  value       = aws_redshift_cluster.main.cluster_identifier
}

output "endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.main.endpoint
}

output "arn" {
  description = "Redshift cluster ARN"
  value       = aws_redshift_cluster.main.arn
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_redshift_cluster.main.database_name
}

output "master_username" {
  description = "Master username"
  value       = aws_redshift_cluster.main.master_username
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.redshift_password.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for S3 access"
  value       = aws_iam_role.redshift_s3.arn
}
