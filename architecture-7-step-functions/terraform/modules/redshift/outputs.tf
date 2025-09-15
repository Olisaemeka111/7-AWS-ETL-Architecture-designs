# Redshift Module Outputs

output "cluster_identifier" {
  description = "Redshift cluster identifier"
  value       = aws_redshift_cluster.main.cluster_identifier
}

output "cluster_arn" {
  description = "Redshift cluster ARN"
  value       = aws_redshift_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.main.endpoint
}

output "cluster_port" {
  description = "Redshift cluster port"
  value       = aws_redshift_cluster.main.port
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_redshift_cluster.main.database_name
}

output "master_username" {
  description = "Master username"
  value       = aws_redshift_cluster.main.master_username
}
