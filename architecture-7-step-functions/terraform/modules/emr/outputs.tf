# EMR Module Outputs

output "cluster_id" {
  description = "ID of the EMR cluster"
  value       = var.enabled ? aws_emr_cluster.cluster[0].id : null
}

output "cluster_arn" {
  description = "ARN of the EMR cluster"
  value       = var.enabled ? aws_emr_cluster.cluster[0].arn : null
}

output "cluster_name" {
  description = "Name of the EMR cluster"
  value       = var.enabled ? aws_emr_cluster.cluster[0].name : null
}
