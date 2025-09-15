# Lambda Module Outputs

output "function_names" {
  description = "Names of the Lambda functions"
  value       = { for k, v in aws_lambda_function.functions : k => v.function_name }
}

output "function_arns" {
  description = "ARNs of the Lambda functions"
  value       = { for k, v in aws_lambda_function.functions : k => v.arn }
}
