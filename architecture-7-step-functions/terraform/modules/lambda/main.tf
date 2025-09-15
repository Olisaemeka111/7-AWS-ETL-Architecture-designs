# Lambda Module for Step Functions ETL

# Lambda Functions
resource "aws_lambda_function" "functions" {
  for_each = var.functions

  function_name = each.value.name
  role         = var.iam_role_arn
  handler      = each.value.handler
  runtime      = each.value.runtime
  timeout      = each.value.timeout
  memory_size  = each.value.memory_size

  filename         = each.value.source_path
  source_code_hash = filebase64sha256(each.value.source_path)

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = each.value.environment_variables
  }

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

# Note: IAM role and policies are managed by the IAM module

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.functions

  name              = "/aws/lambda/${each.value.name}"
  retention_in_days = 14

  tags = var.tags
}
