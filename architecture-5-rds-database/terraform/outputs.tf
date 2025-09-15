# Architecture 5: RDS Database ETL - Outputs

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

# RDS Source Outputs
output "rds_source_endpoint" {
  description = "Endpoint of the source RDS instance"
  value       = module.rds_source.endpoint
}

output "rds_source_port" {
  description = "Port of the source RDS instance"
  value       = module.rds_source.port
}

output "rds_source_arn" {
  description = "ARN of the source RDS instance"
  value       = module.rds_source.db_instance_arn
}

output "rds_source_id" {
  description = "ID of the source RDS instance"
  value       = module.rds_source.db_instance_id
}

# RDS Target Outputs
output "rds_target_endpoint" {
  description = "Endpoint of the target RDS instance"
  value       = module.rds_target.endpoint
}

output "rds_target_port" {
  description = "Port of the target RDS instance"
  value       = module.rds_target.port
}

output "rds_target_arn" {
  description = "ARN of the target RDS instance"
  value       = module.rds_target.db_instance_arn
}

output "rds_target_id" {
  description = "ID of the target RDS instance"
  value       = module.rds_target.db_instance_id
}

# Aurora Outputs (if enabled)
output "aurora_cluster_endpoint" {
  description = "Endpoint of the Aurora cluster"
  value       = var.enable_aurora ? module.aurora[0].cluster_endpoint : null
}

output "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = var.enable_aurora ? module.aurora[0].cluster_arn : null
}

output "aurora_cluster_id" {
  description = "ID of the Aurora cluster"
  value       = var.enable_aurora ? module.aurora[0].cluster_id : null
}

# DMS Outputs
output "dms_replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = module.dms.replication_instance_id
}

output "dms_replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = module.dms.replication_instance_arn
}

output "dms_source_endpoint_id" {
  description = "ID of the DMS source endpoint"
  value       = module.dms.source_endpoint_id
}

output "dms_target_endpoint_id" {
  description = "ID of the DMS target endpoint"
  value       = module.dms.target_endpoint_id
}

output "dms_replication_task_ids" {
  description = "IDs of the DMS replication tasks"
  value       = module.dms.replication_task_ids
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

output "etl_processor_function_name" {
  description = "Name of the ETL processor Lambda function"
  value       = module.lambda.function_names["etl-processor"]
}

output "data_validator_function_name" {
  description = "Name of the data validator Lambda function"
  value       = module.lambda.function_names["data-validator"]
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

# EventBridge Outputs
output "eventbridge_rule_names" {
  description = "Names of the EventBridge rules"
  value       = module.eventbridge.rule_names
}

output "etl_schedule_rule_name" {
  description = "Name of the ETL schedule rule"
  value       = module.eventbridge.rule_names["etl-schedule"]
}

output "dms_monitoring_rule_name" {
  description = "Name of the DMS monitoring rule"
  value       = module.eventbridge.rule_names["dms-monitoring"]
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
output "rds_source_role_arn" {
  description = "ARN of the RDS source role"
  value       = module.iam.rds_source_role_arn
}

output "rds_target_role_arn" {
  description = "ARN of the RDS target role"
  value       = module.iam.rds_target_role_arn
}

output "dms_role_arn" {
  description = "ARN of the DMS role"
  value       = module.iam.dms_role_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

# Connection Information
output "database_connections" {
  description = "Database connection information"
  value = {
    source_database = {
      endpoint = module.rds_source.endpoint
      port     = module.rds_source.port
      database = var.source_db_name
      username = var.source_db_username
    }
    target_database = {
      endpoint = module.rds_target.endpoint
      port     = module.rds_target.port
      database = var.target_db_name
      username = var.target_db_username
    }
    aurora_cluster = var.enable_aurora ? {
      endpoint = module.aurora[0].cluster_endpoint
      port     = module.aurora[0].port
      database = var.aurora_database_name
      username = var.aurora_master_username
    } : null
    redshift_cluster = var.enable_redshift ? {
      endpoint = module.redshift[0].cluster_endpoint
      port     = module.redshift[0].port
      database = var.redshift_database_name
      username = var.redshift_master_username
    } : null
  }
}

output "dms_console_urls" {
  description = "AWS DMS console URLs"
  value = {
    replication_instances = "https://${var.aws_region}.console.aws.amazon.com/dms/home?region=${var.aws_region}#replicationInstances"
    replication_tasks    = "https://${var.aws_region}.console.aws.amazon.com/dms/home?region=${var.aws_region}#replicationTasks"
    endpoints           = "https://${var.aws_region}.console.aws.amazon.com/dms/home?region=${var.aws_region}#endpoints"
  }
}

output "rds_console_urls" {
  description = "AWS RDS console URLs"
  value = {
    source_instance = "https://${var.aws_region}.console.aws.amazon.com/rds/home?region=${var.aws_region}#database:id=${module.rds_source.db_instance_id};is-cluster=false"
    target_instance = "https://${var.aws_region}.console.aws.amazon.com/rds/home?region=${var.aws_region}#database:id=${module.rds_target.db_instance_id};is-cluster=false"
    aurora_cluster  = var.enable_aurora ? "https://${var.aws_region}.console.aws.amazon.com/rds/home?region=${var.aws_region}#database:id=${module.aurora[0].cluster_id};is-cluster=true" : null
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
    rds_source = {
      instance_class = var.source_instance_class
      estimated_cost = "~$15-50 USD per month"
    }
    rds_target = {
      instance_class = var.target_instance_class
      estimated_cost = "~$15-50 USD per month"
    }
    aurora_cluster = var.enable_aurora ? {
      instance_class = var.aurora_instance_class
      instance_count = var.aurora_instance_count
      estimated_cost = "~$100-300 USD per month"
    } : null
    dms_replication = {
      instance_class = var.dms_instance_class
      estimated_cost = "~$50-150 USD per month"
    }
    lambda_functions = {
      estimated_cost = "~$5-20 USD per month"
    }
    s3_storage = "~$2.30 USD per 100GB"
    redshift   = var.enable_redshift ? "~$180 USD per month (dc2.large)" : "Not enabled"
    total_estimate = var.enable_aurora && var.enable_redshift ? "~$400-800 USD per month" : 
                     var.enable_aurora ? "~$200-500 USD per month" : 
                     var.enable_redshift ? "~$300-600 USD per month" : "~$100-300 USD per month"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    cloudwatch_dashboard = module.cloudwatch.dashboard_url
    rds_source_id      = module.rds_source.db_instance_id
    rds_target_id      = module.rds_target.db_instance_id
    dms_instance_id    = module.dms.replication_instance_id
    log_groups         = module.cloudwatch.log_group_names
  }
}

# Access Information
output "access_info" {
  description = "Access information for the databases"
  value = {
    source_database_connection = "psql -h ${module.rds_source.endpoint} -p ${module.rds_source.port} -U ${var.source_db_username} -d ${var.source_db_name}"
    target_database_connection = "psql -h ${module.rds_target.endpoint} -p ${module.rds_target.port} -U ${var.target_db_username} -d ${var.target_db_name}"
    aurora_connection = var.enable_aurora ? "psql -h ${module.aurora[0].cluster_endpoint} -p ${module.aurora[0].port} -U ${var.aurora_master_username} -d ${var.aurora_database_name}" : null
    redshift_connection = var.enable_redshift ? "psql -h ${module.redshift[0].cluster_endpoint} -p ${module.redshift[0].port} -U ${var.redshift_master_username} -d ${var.redshift_database_name}" : null
    region = var.aws_region
  }
}
