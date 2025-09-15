# Architecture 1: Serverless ETL with Lambda - Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# S3 Outputs
output "staging_bucket_name" {
  description = "Name of the S3 staging bucket"
  value       = module.s3.staging_bucket_name
}

output "staging_bucket_arn" {
  description = "ARN of the S3 staging bucket"
  value       = module.s3.staging_bucket_arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

# Redshift Outputs
output "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  value       = module.redshift.endpoint
  sensitive   = true
}

output "redshift_port" {
  description = "Redshift cluster port"
  value       = module.redshift.port
}

output "redshift_database_name" {
  description = "Redshift database name"
  value       = module.redshift.database_name
}

# SQS Outputs
output "processing_queue_url" {
  description = "URL of the processing SQS queue"
  value       = module.sqs.processing_queue_url
}

output "processing_queue_arn" {
  description = "ARN of the processing SQS queue"
  value       = module.sqs.processing_queue_arn
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = module.sqs.dlq_url
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = module.sqs.dlq_arn
}

# Lambda Outputs
output "extract_lambda_name" {
  description = "Name of the extract Lambda function"
  value       = module.lambda.extract_lambda_name
}

output "extract_lambda_arn" {
  description = "ARN of the extract Lambda function"
  value       = module.lambda.extract_lambda_arn
}

output "transform_lambda_name" {
  description = "Name of the transform Lambda function"
  value       = module.lambda.transform_lambda_name
}

output "transform_lambda_arn" {
  description = "ARN of the transform Lambda function"
  value       = module.lambda.transform_lambda_arn
}

output "load_lambda_name" {
  description = "Name of the load Lambda function"
  value       = module.lambda.load_lambda_name
}

output "load_lambda_arn" {
  description = "ARN of the load Lambda function"
  value       = module.lambda.load_lambda_arn
}

# EventBridge Outputs
output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = module.eventbridge.rule_arn
}

# IAM Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

# Connection Information
output "connection_info" {
  description = "Connection information for databases"
  value = {
    source_rds = {
      endpoint = module.rds.endpoint
      port     = module.rds.port
      database = module.rds.database_name
    }
    target_redshift = {
      endpoint = module.redshift.endpoint
      port     = module.redshift.port
      database = module.redshift.database_name
    }
  }
  sensitive = true
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    lambda = "~$20-50 (based on 1M requests)"
    s3     = "~$5-15 (based on 100GB storage)"
    redshift = "~$180 (dc2.large, 24/7)"
    sqs    = "~$1-5 (based on 1M messages)"
    total  = "~$206-250/month"
  }
}
