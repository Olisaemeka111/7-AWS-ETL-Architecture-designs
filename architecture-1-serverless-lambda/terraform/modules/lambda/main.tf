# Lambda Module for Serverless ETL Architecture

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_execution" {
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

# IAM Policy for Lambda execution
resource "aws_iam_role_policy" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.staging_bucket_arn,
          "${var.staging_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          var.processing_queue_arn,
          var.dlq_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "redshift:DescribeClusters",
          "redshift:GetClusterCredentials"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "extract_lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-extract"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "transform_lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-transform"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "load_lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-load"
  retention_in_days = 14

  tags = var.tags
}

# Extract Lambda Function
resource "aws_lambda_function" "extract" {
  filename         = data.archive_file.extract_lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-extract"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "extract.lambda_handler"
  source_code_hash = data.archive_file.extract_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      SOURCE_RDS_ENDPOINT = var.source_rds_endpoint
      PROCESSING_QUEUE_URL = var.processing_queue_url
      STAGING_BUCKET_NAME = var.staging_bucket_name
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.extract_lambda,
    aws_iam_role_policy.lambda_execution
  ]

  tags = var.tags
}

# Transform Lambda Function
resource "aws_lambda_function" "transform" {
  filename         = data.archive_file.transform_lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-transform"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "transform.lambda_handler"
  source_code_hash = data.archive_file.transform_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      STAGING_BUCKET_NAME = var.staging_bucket_name
      PROCESSING_QUEUE_URL = var.processing_queue_url
      DLQ_URL = var.dlq_url
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.transform_lambda,
    aws_iam_role_policy.lambda_execution
  ]

  tags = var.tags
}

# Load Lambda Function
resource "aws_lambda_function" "load" {
  filename         = data.archive_file.load_lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-load"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "load.lambda_handler"
  source_code_hash = data.archive_file.load_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      TARGET_REDSHIFT_ENDPOINT = var.target_redshift_endpoint
      STAGING_BUCKET_NAME = var.staging_bucket_name
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.load_lambda,
    aws_iam_role_policy.lambda_execution
  ]

  tags = var.tags
}

# SQS Event Source Mapping for Transform Lambda
resource "aws_lambda_event_source_mapping" "transform_sqs" {
  event_source_arn = var.processing_queue_arn
  function_name    = aws_lambda_function.transform.arn
  batch_size       = 10
  maximum_batching_window_in_seconds = 5
}

# Data sources for Lambda zip files
data "archive_file" "extract_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/extract"
  output_path = "${path.module}/extract_lambda.zip"
}

data "archive_file" "transform_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/transform"
  output_path = "${path.module}/transform_lambda.zip"
}

data "archive_file" "load_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/load"
  output_path = "${path.module}/load_lambda.zip"
}
