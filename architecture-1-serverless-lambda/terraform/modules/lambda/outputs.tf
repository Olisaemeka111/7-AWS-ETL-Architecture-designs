# Lambda Module Outputs

output "extract_lambda_arn" {
  description = "ARN of the extract Lambda function"
  value       = aws_lambda_function.extract.arn
}

output "transform_lambda_arn" {
  description = "ARN of the transform Lambda function"
  value       = aws_lambda_function.transform.arn
}

output "load_lambda_arn" {
  description = "ARN of the load Lambda function"
  value       = aws_lambda_function.load.arn
}

output "extract_lambda_name" {
  description = "Name of the extract Lambda function"
  value       = aws_lambda_function.extract.function_name
}

output "transform_lambda_name" {
  description = "Name of the transform Lambda function"
  value       = aws_lambda_function.transform.function_name
}

output "load_lambda_name" {
  description = "Name of the load Lambda function"
  value       = aws_lambda_function.load.function_name
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}
