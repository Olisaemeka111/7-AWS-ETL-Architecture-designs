# IAM Module Outputs

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "step_functions_execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = aws_iam_role.step_functions_execution_role.arn
}

output "eventbridge_step_functions_role_arn" {
  description = "ARN of the EventBridge Step Functions role"
  value       = aws_iam_role.eventbridge_step_functions_role.arn
}

output "glue_service_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.glue_service_role.arn
}

output "emr_service_role_arn" {
  description = "ARN of the EMR service role"
  value       = var.emr_cluster_arn != null ? aws_iam_role.emr_service_role[0].arn : null
}

output "emr_instance_profile_arn" {
  description = "ARN of the EMR instance profile"
  value       = var.emr_cluster_arn != null ? aws_iam_instance_profile.emr_instance_profile[0].arn : null
}
