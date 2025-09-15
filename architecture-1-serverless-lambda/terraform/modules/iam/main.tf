# IAM Module - Main Configuration

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-${var.environment}-lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC access policy (if Lambda needs VPC access)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.enable_vpc_access ? 1 : 0
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-${var.environment}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          for bucket_arn in var.s3_bucket_arns : "${bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# Custom policy for SQS access
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "${var.project_name}-${var.environment}-lambda-sqs-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arns
      }
    ]
  })
}

# Custom policy for RDS access
resource "aws_iam_role_policy" "lambda_rds_policy" {
  count = var.enable_rds_access ? 1 : 0
  name  = "${var.project_name}-${var.environment}-lambda-rds-policy"
  role  = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = var.rds_db_arns
      }
    ]
  })
}

# Custom policy for Redshift access
resource "aws_iam_role_policy" "lambda_redshift_policy" {
  count = var.enable_redshift_access ? 1 : 0
  name  = "${var.project_name}-${var.environment}-lambda-redshift-policy"
  role  = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift:DescribeClusters",
          "redshift:GetClusterCredentials"
        ]
        Resource = var.redshift_cluster_arns
      }
    ]
  })
}

# Custom policy for CloudWatch metrics
resource "aws_iam_role_policy" "lambda_cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-lambda-cloudwatch-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-${var.environment}-eventbridge-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Policy for EventBridge to invoke Lambda
resource "aws_iam_role_policy" "eventbridge_lambda_policy" {
  name = "${var.project_name}-${var.environment}-eventbridge-lambda-policy"
  role = aws_iam_role.eventbridge_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_function_arns
      }
    ]
  })
}

# IAM Role for SQS (if using SQS as event source)
resource "aws_iam_role" "sqs_role" {
  count = var.enable_sqs_event_source ? 1 : 0
  name  = "${var.project_name}-${var.environment}-sqs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Policy for SQS to invoke Lambda
resource "aws_iam_role_policy" "sqs_lambda_policy" {
  count = var.enable_sqs_event_source ? 1 : 0
  name  = "${var.project_name}-${var.environment}-sqs-lambda-policy"
  role  = aws_iam_role.sqs_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_function_arns
      }
    ]
  })
}

# IAM Role for API Gateway (if using API Gateway)
resource "aws_iam_role" "api_gateway_role" {
  count = var.enable_api_gateway ? 1 : 0
  name  = "${var.project_name}-${var.environment}-api-gateway-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Policy for API Gateway to invoke Lambda
resource "aws_iam_role_policy" "api_gateway_lambda_policy" {
  count = var.enable_api_gateway ? 1 : 0
  name  = "${var.project_name}-${var.environment}-api-gateway-lambda-policy"
  role  = aws_iam_role.api_gateway_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_function_arns
      }
    ]
  })
}
