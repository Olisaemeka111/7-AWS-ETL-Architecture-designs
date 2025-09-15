# Architecture 7: Step Functions ETL - Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
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

output "aggregated_data_bucket" {
  description = "Name of the aggregated data S3 bucket"
  value       = module.s3.bucket_names["aggregated-data"]
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

output "etl_extract_function_name" {
  description = "Name of the ETL extract function"
  value       = module.lambda.function_names["etl-extract"]
}

output "etl_transform_function_name" {
  description = "Name of the ETL transform function"
  value       = module.lambda.function_names["etl-transform"]
}

output "etl_validate_function_name" {
  description = "Name of the ETL validate function"
  value       = module.lambda.function_names["etl-validate"]
}

output "etl_load_function_name" {
  description = "Name of the ETL load function"
  value       = module.lambda.function_names["etl-load"]
}

output "etl_error_handler_function_name" {
  description = "Name of the ETL error handler function"
  value       = module.lambda.function_names["etl-error-handler"]
}

# Glue Outputs
output "glue_job_names" {
  description = "Names of the Glue jobs"
  value       = module.glue.job_names
}

output "glue_crawler_names" {
  description = "Names of the Glue crawlers"
  value       = module.glue.crawler_names
}

output "glue_database_names" {
  description = "Names of the Glue databases"
  value       = module.glue.database_names
}

# EMR Outputs (if enabled)
output "emr_cluster_id" {
  description = "ID of the EMR cluster"
  value       = var.enable_emr ? module.emr[0].cluster_id : null
}

output "emr_cluster_arn" {
  description = "ARN of the EMR cluster"
  value       = var.enable_emr ? module.emr[0].cluster_arn : null
}

output "emr_cluster_name" {
  description = "Name of the EMR cluster"
  value       = var.enable_emr ? module.emr[0].cluster_name : null
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

# SNS Outputs
output "sns_topic_arns" {
  description = "ARNs of the SNS topics"
  value       = module.sns.topic_arns
}

output "etl_alerts_topic_arn" {
  description = "ARN of the ETL alerts topic"
  value       = module.sns.topic_arns["etl-alerts"]
}

output "etl_notifications_topic_arn" {
  description = "ARN of the ETL notifications topic"
  value       = module.sns.topic_arns["etl-notifications"]
}

# Step Functions Outputs
output "step_functions_state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = module.step_functions.state_machine_arn
}

output "step_functions_state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = module.step_functions.state_machine_name
}

# EventBridge Outputs
output "eventbridge_rule_names" {
  description = "Names of the EventBridge rules"
  value       = module.eventbridge.rule_names
}

output "etl_schedule_rule_name" {
  description = "Name of the ETL schedule rule"
  value       = module.eventbridge.rule_names["etl-schedule"]
}

output "etl_monitoring_rule_name" {
  description = "Name of the ETL monitoring rule"
  value       = module.eventbridge.rule_names["etl-monitoring"]
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

output "lambda_task_role_arn" {
  description = "ARN of the Lambda task role"
  value       = module.iam.lambda_task_role_arn
}

output "step_functions_execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = module.iam.step_functions_execution_role_arn
}

output "eventbridge_step_functions_role_arn" {
  description = "ARN of the EventBridge Step Functions role"
  value       = module.iam.eventbridge_step_functions_role_arn
}

# Step Functions Console URLs
output "step_functions_console_urls" {
  description = "AWS Step Functions console URLs"
  value = {
    state_machine_details = "https://${var.aws_region}.console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${module.step_functions.state_machine_arn}"
    executions_list      = "https://${var.aws_region}.console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${module.step_functions.state_machine_arn}/executions"
  }
}

# Lambda Console URLs
output "lambda_console_urls" {
  description = "AWS Lambda console URLs"
  value = {
    functions_list = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions"
    extract_function = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.lambda.function_names["etl-extract"]}"
    transform_function = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.lambda.function_names["etl-transform"]}"
    validate_function = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.lambda.function_names["etl-validate"]}"
    load_function = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.lambda.function_names["etl-load"]}"
    error_handler_function = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${module.lambda.function_names["etl-error-handler"]}"
  }
}

# Glue Console URLs
output "glue_console_urls" {
  description = "AWS Glue console URLs"
  value = {
    jobs_list = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#etl:tab=jobs"
    transform_job = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#etl:tab=jobs;name=${module.glue.job_names["etl-transform-job"]}"
    crawlers_list = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#catalog:tab=crawlers"
  }
}

# EMR Console URLs (if enabled)
output "emr_console_urls" {
  description = "AWS EMR console URLs"
  value = var.enable_emr ? {
    clusters_list = "https://${var.aws_region}.console.aws.amazon.com/emr/home?region=${var.aws_region}#cluster-list"
    cluster_details = "https://${var.aws_region}.console.aws.amazon.com/emr/home?region=${var.aws_region}#cluster-details:${module.emr[0].cluster_id}"
  } : null
}

# Redshift Console URLs (if enabled)
output "redshift_console_urls" {
  description = "AWS Redshift console URLs"
  value = var.enable_redshift ? {
    clusters_list = "https://${var.aws_region}.console.aws.amazon.com/redshiftv2/home?region=${var.aws_region}#clusters"
    cluster_details = "https://${var.aws_region}.console.aws.amazon.com/redshiftv2/home?region=${var.aws_region}#cluster-details/${module.redshift[0].cluster_identifier}"
  } : null
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
    step_functions_type = var.step_functions_type
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    step_functions = {
      type = var.step_functions_type
      estimated_cost = var.step_functions_type == "EXPRESS" ? "~$0.025 USD per 1000 state transitions" : "~$0.025 USD per 1000 state transitions"
    }
    lambda_functions = {
      estimated_cost = "~$20-100 USD per month"
    }
    glue_jobs = {
      estimated_cost = "~$10-50 USD per month"
    }
    emr_cluster = var.enable_emr ? {
      estimated_cost = "~$100-500 USD per month"
    } : null
    redshift = var.enable_redshift ? {
      estimated_cost = "~$180 USD per month (dc2.large)"
    } : null
    s3_storage = "~$2.30 USD per 100GB"
    sns_notifications = "~$0.50 USD per 1000 notifications"
    total_estimate = var.enable_emr && var.enable_redshift ? "~$350-900 USD per month" : var.enable_emr ? "~$150-700 USD per month" : var.enable_redshift ? "~$250-400 USD per month" : "~$50-200 USD per month"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    cloudwatch_dashboard = module.cloudwatch.dashboard_url
    step_functions_arn = module.step_functions.state_machine_arn
    sns_alerts_topic = module.sns.topic_arns["etl-alerts"]
    sns_notifications_topic = module.sns.topic_arns["etl-notifications"]
    log_groups = module.cloudwatch.log_group_names
  }
}

# Access Information
output "access_info" {
  description = "Access information for the ETL pipeline"
  value = {
    step_functions_name = module.step_functions.state_machine_name
    step_functions_arn = module.step_functions.state_machine_arn
    region = var.aws_region
    s3_buckets = module.s3.bucket_names
    redshift_endpoint = var.enable_redshift ? module.redshift[0].cluster_endpoint : null
    emr_cluster_id = var.enable_emr ? module.emr[0].cluster_id : null
  }
}

# ETL Pipeline Information
output "etl_pipeline_info" {
  description = "ETL pipeline configuration information"
  value = {
    schedule_expression = var.etl_schedule_expression
    batch_size = var.etl_batch_size
    max_retries = var.etl_max_retries
    retry_delay = var.etl_retry_delay
    data_quality_enabled = var.enable_data_quality_checks
    data_quality_threshold = var.data_quality_threshold
    disaster_recovery_enabled = var.enable_disaster_recovery
  }
}

# Execution Commands
output "execution_commands" {
  description = "Commands for executing the ETL pipeline"
  value = {
    start_execution = "aws stepfunctions start-execution --state-machine-arn ${module.step_functions.state_machine_arn} --name 'etl-execution-$(date +%Y%m%d-%H%M%S)'"
    list_executions = "aws stepfunctions list-executions --state-machine-arn ${module.step_functions.state_machine_arn}"
    describe_execution = "aws stepfunctions describe-execution --execution-arn <execution-arn>"
    get_execution_history = "aws stepfunctions get-execution-history --execution-arn <execution-arn>"
  }
}
