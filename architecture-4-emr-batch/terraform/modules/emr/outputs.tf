# EMR Module - Outputs

output "cluster_id" {
  description = "ID of the EMR cluster"
  value       = aws_emr_cluster.emr_cluster.id
}

output "cluster_arn" {
  description = "ARN of the EMR cluster"
  value       = aws_emr_cluster.emr_cluster.arn
}

output "cluster_name" {
  description = "Name of the EMR cluster"
  value       = aws_emr_cluster.emr_cluster.name
}

output "master_public_dns" {
  description = "Public DNS name of the EMR master node"
  value       = aws_emr_cluster.emr_cluster.master_public_dns
}

output "master_private_dns" {
  description = "Private DNS name of the EMR master node"
  value       = aws_emr_cluster.emr_cluster.master_private_dns
}

output "cluster_endpoint" {
  description = "Endpoint of the EMR cluster"
  value       = aws_emr_cluster.emr_cluster.master_public_dns
}

output "service_role_arn" {
  description = "ARN of the EMR service role"
  value       = aws_iam_role.emr_service_role.arn
}

output "instance_profile_arn" {
  description = "ARN of the EMR instance profile"
  value       = aws_iam_instance_profile.emr_instance_profile.arn
}

output "security_group_id" {
  description = "ID of the EMR security group"
  value       = aws_security_group.emr_security_group.id
}

output "autoscaling_role_arn" {
  description = "ARN of the EMR auto-scaling role"
  value       = var.enable_auto_scaling ? aws_iam_role.emr_autoscaling_role[0].arn : null
}

output "autoscaling_target_id" {
  description = "ID of the EMR auto-scaling target"
  value       = var.enable_auto_scaling ? aws_appautoscaling_target.emr_autoscaling_target[0].id : null
}
