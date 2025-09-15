# Architecture 2: AWS Glue ETL Pipeline - Outputs

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

# S3 Data Lake Outputs
output "s3_bucket_names" {
  description = "Names of the S3 data lake buckets"
  value       = module.s3_data_lake.bucket_names
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 data lake buckets"
  value       = module.s3_data_lake.bucket_arns
}

output "raw_zone_bucket" {
  description = "Name of the raw zone S3 bucket"
  value       = module.s3_data_lake.bucket_names["raw-zone"]
}

output "clean_zone_bucket" {
  description = "Name of the clean zone S3 bucket"
  value       = module.s3_data_lake.bucket_names["clean-zone"]
}

output "aggregated_zone_bucket" {
  description = "Name of the aggregated zone S3 bucket"
  value       = module.s3_data_lake.bucket_names["aggregated-zone"]
}

# Glue Outputs
output "glue_job_names" {
  description = "Names of the Glue ETL jobs"
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

output "glue_workflow_name" {
  description = "Name of the Glue workflow"
  value       = module.glue.workflow_name
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

# IAM Outputs
output "glue_service_role_arn" {
  description = "ARN of the Glue service role"
  value       = module.iam.glue_service_role_arn
}

output "glue_job_role_arn" {
  description = "ARN of the Glue job role"
  value       = module.iam.glue_job_role_arn
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

# Connection Information
output "data_lake_endpoints" {
  description = "Data lake S3 endpoints"
  value = {
    raw_zone      = "s3://${module.s3_data_lake.bucket_names["raw-zone"]}"
    clean_zone    = "s3://${module.s3_data_lake.bucket_names["clean-zone"]}"
    aggregated_zone = "s3://${module.s3_data_lake.bucket_names["aggregated-zone"]}"
    temp_zone     = "s3://${module.s3_data_lake.bucket_names["temp-zone"]}"
    logs_zone     = "s3://${module.s3_data_lake.bucket_names["logs-zone"]}"
  }
}

output "glue_console_urls" {
  description = "AWS Glue console URLs"
  value = {
    jobs      = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#etl:tab=jobs"
    crawlers  = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#catalog:tab=crawlers"
    databases = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#catalog:tab=databases"
    workflows = "https://${var.aws_region}.console.aws.amazon.com/glue/home?region=${var.aws_region}#etl:tab=workflows"
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
    glue_jobs = {
      extract_job   = "${var.extract_job_dpu * 0.44 * 24 * 30} USD (assuming 24/7)"
      transform_job = "${var.transform_job_dpu * 0.44 * 24 * 30} USD (assuming 24/7)"
      load_job      = "${var.load_job_dpu * 0.44 * 24 * 30} USD (assuming 24/7)"
    }
    s3_storage = "~$2.30 USD per 100GB"
    redshift   = var.enable_redshift ? "~$180 USD per month (dc2.large)" : "Not enabled"
    total_estimate = var.enable_redshift ? "~$200-300 USD per month" : "~$20-50 USD per month"
  }
}
