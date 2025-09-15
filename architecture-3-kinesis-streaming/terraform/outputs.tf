# Architecture 3: Kinesis Streaming ETL - Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.vpc.security_group_id
}

# S3 Outputs
output "s3_bucket_names" {
  description = "Names of the S3 buckets"
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = module.s3.bucket_arns
}

output "raw_data_bucket" {
  description = "Name of the raw data S3 bucket"
  value       = module.s3.bucket_names["raw-data"]
}

output "processed_data_bucket" {
  description = "Name of the processed data S3 bucket"
  value       = module.s3.bucket_names["processed-data"]
}

# Kinesis Outputs
output "kinesis_stream_names" {
  description = "Names of the Kinesis streams"
  value       = module.kinesis.stream_names
}

output "kinesis_stream_arns" {
  description = "ARNs of the Kinesis streams"
  value       = module.kinesis.stream_arns
}

output "main_stream_name" {
  description = "Name of the main Kinesis stream"
  value       = module.kinesis.stream_names["main-stream"]
}

output "analytics_stream_name" {
  description = "Name of the analytics Kinesis stream"
  value       = module.kinesis.stream_names["analytics-stream"]
}

output "kinesis_analytics_applications" {
  description = "Names of the Kinesis Analytics applications"
  value       = module.kinesis.analytics_applications
}

output "firehose_delivery_streams" {
  description = "Names of the Kinesis Data Firehose delivery streams"
  value       = module.kinesis.firehose_delivery_streams
}

# Lambda Outputs
output "lambda_function_names" {
  description = "Names of the Lambda functions"
  value       = module.lambda.function_names
}

output "lambda_function_arns" {
  description = "ARNs of the Lambda functions"
  value       = module.lambda.function_arns
}

output "stream_processor_function_name" {
  description = "Name of the stream processor Lambda function"
  value       = module.lambda.function_names["stream-processor"]
}

output "data_enricher_function_name" {
  description = "Name of the data enricher Lambda function"
  value       = module.lambda.function_names["data-enricher"]
}

output "anomaly_detector_function_name" {
  description = "Name of the anomaly detector Lambda function"
  value       = module.lambda.function_names["anomaly-detector"]
}

# Redshift Outputs (if enabled)
output "redshift_cluster_identifier" {
  description = "Identifier of the Redshift cluster"
  value       = var.enable_redshift ? module.redshift[0].cluster_identifier : null
}

output "redshift_cluster_endpoint" {
  description = "Endpoint of the Redshift cluster"
  value       = var.enable_redshift ? module.redshift[0].cluster_endpoint : null
}

output "redshift_cluster_arn" {
  description = "ARN of the Redshift cluster"
  value       = var.enable_redshift ? module.redshift[0].cluster_arn : null
}

# OpenSearch Outputs
output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = module.opensearch.domain_name
}

output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = module.opensearch.domain_arn
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch domain"
  value       = module.opensearch.endpoint
}

output "opensearch_kibana_endpoint" {
  description = "Kibana endpoint of the OpenSearch domain"
  value       = module.opensearch.kibana_endpoint
}

# SNS Outputs
output "sns_topic_arns" {
  description = "ARNs of the SNS topics"
  value       = module.sns.topic_arns
}

output "alerts_topic_arn" {
  description = "ARN of the alerts SNS topic"
  value       = module.sns.topic_arns["alerts"]
}

output "notifications_topic_arn" {
  description = "ARN of the notifications SNS topic"
  value       = module.sns.topic_arns["notifications"]
}

# CloudWatch Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.cloudwatch.dashboard_url
}

output "cloudwatch_log_groups" {
  description = "Names of the CloudWatch log groups"
  value       = module.cloudwatch.log_group_names
}

# IAM Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "kinesis_role_arn" {
  description = "ARN of the Kinesis role"
  value       = module.iam.kinesis_role_arn
}

# Connection Information
output "streaming_endpoints" {
  description = "Streaming service endpoints"
  value = {
    main_stream      = "kinesis://${module.kinesis.stream_names["main-stream"]}"
    analytics_stream = "kinesis://${module.kinesis.stream_names["analytics-stream"]}"
    s3_raw_data      = "s3://${module.s3.bucket_names["raw-data"]}"
    s3_processed_data = "s3://${module.s3.bucket_names["processed-data"]}"
    opensearch       = module.opensearch.endpoint
    kibana           = module.opensearch.kibana_endpoint
  }
}

output "aws_console_urls" {
  description = "AWS console URLs for services"
  value = {
    kinesis_streams = "https://${var.aws_region}.console.aws.amazon.com/kinesis/home?region=${var.aws_region}#/streams"
    kinesis_analytics = "https://${var.aws_region}.console.aws.amazon.com/kinesisanalytics/home?region=${var.aws_region}#/applications"
    kinesis_firehose = "https://${var.aws_region}.console.aws.amazon.com/firehose/home?region=${var.aws_region}#/"
    lambda_functions = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions"
    opensearch = "https://${var.aws_region}.console.aws.amazon.com/es/home?region=${var.aws_region}#domain:resource=${module.opensearch.domain_name}"
    redshift = var.enable_redshift ? "https://${var.aws_region}.console.aws.amazon.com/redshift/home?region=${var.aws_region}#cluster-details?cluster=${module.redshift[0].cluster_identifier}" : null
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    aws_region      = var.aws_region
    deployment_time = timestamp()
    terraform_version = terraform.version
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    kinesis_streams = {
      main_stream = "${var.kinesis_shard_count * 0.014 * 24 * 30} USD (shard-hours)"
      analytics_stream = "${var.analytics_shard_count * 0.014 * 24 * 30} USD (shard-hours)"
    }
    kinesis_analytics = "~$50-100 USD (depending on KPU usage)"
    kinesis_firehose = "~$0.029 USD per GB ingested"
    lambda_functions = "~$10-30 USD (depending on invocations)"
    opensearch = "~$50-200 USD (depending on instance type and count)"
    redshift = var.enable_redshift ? "~$180 USD per month (dc2.large)" : "Not enabled"
    s3_storage = "~$2.30 USD per 100GB"
    total_estimate = var.enable_redshift ? "~$300-600 USD per month" : "~$120-400 USD per month"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    cloudwatch_dashboard = module.cloudwatch.dashboard_url
    alert_emails = var.alert_emails
    notification_emails = var.notification_emails
    log_groups = module.cloudwatch.log_group_names
  }
}
