# IAM Module - Outputs

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.name
}

output "eventbridge_role_arn" {
  description = "ARN of the EventBridge role"
  value       = aws_iam_role.eventbridge_role.arn
}

output "eventbridge_role_name" {
  description = "Name of the EventBridge role"
  value       = aws_iam_role.eventbridge_role.name
}

output "sqs_role_arn" {
  description = "ARN of the SQS role (if enabled)"
  value       = var.enable_sqs_event_source ? aws_iam_role.sqs_role[0].arn : null
}

output "sqs_role_name" {
  description = "Name of the SQS role (if enabled)"
  value       = var.enable_sqs_event_source ? aws_iam_role.sqs_role[0].name : null
}

output "api_gateway_role_arn" {
  description = "ARN of the API Gateway role (if enabled)"
  value       = var.enable_api_gateway ? aws_iam_role.api_gateway_role[0].arn : null
}

output "api_gateway_role_name" {
  description = "Name of the API Gateway role (if enabled)"
  value       = var.enable_api_gateway ? aws_iam_role.api_gateway_role[0].name : null
}
