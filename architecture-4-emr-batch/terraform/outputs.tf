# Architecture 4: EMR Batch ETL - Outputs

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

output "aggregated_data_bucket" {
  description = "Name of the aggregated data S3 bucket"
  value       = module.s3.bucket_names["aggregated-data"]
}

# EMR Outputs
output "emr_cluster_id" {
  description = "ID of the EMR cluster"
  value       = module.emr.cluster_id
}

output "emr_cluster_arn" {
  description = "ARN of the EMR cluster"
  value       = module.emr.cluster_arn
}

output "emr_cluster_name" {
  description = "Name of the EMR cluster"
  value       = module.emr.cluster_name
}

output "emr_master_public_dns" {
  description = "Public DNS name of the EMR master node"
  value       = module.emr.master_public_dns
}

output "emr_master_private_dns" {
  description = "Private DNS name of the EMR master node"
  value       = module.emr.master_private_dns
}

output "emr_cluster_endpoint" {
  description = "Endpoint of the EMR cluster"
  value       = module.emr.cluster_endpoint
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

# Airflow Outputs (if enabled)
output "airflow_environment_name" {
  description = "Name of the Airflow environment"
  value       = var.enable_airflow ? module.airflow[0].environment_name : null
}

output "airflow_webserver_url" {
  description = "URL of the Airflow webserver"
  value       = var.enable_airflow ? module.airflow[0].webserver_url : null
}

output "airflow_environment_arn" {
  description = "ARN of the Airflow environment"
  value       = var.enable_airflow ? module.airflow[0].environment_arn : null
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
output "emr_service_role_arn" {
  description = "ARN of the EMR service role"
  value       = module.iam.emr_service_role_arn
}

output "emr_instance_profile_arn" {
  description = "ARN of the EMR instance profile"
  value       = module.iam.emr_instance_profile_arn
}

# Connection Information
output "data_lake_endpoints" {
  description = "Data lake S3 endpoints"
  value = {
    raw_data      = "s3://${module.s3.bucket_names["raw-data"]}"
    processed_data = "s3://${module.s3.bucket_names["processed-data"]}"
    aggregated_data = "s3://${module.s3.bucket_names["aggregated-data"]}"
    logs          = "s3://${module.s3.bucket_names["logs"]}"
  }
}

output "emr_console_urls" {
  description = "AWS EMR console URLs"
  value = {
    cluster_details = "https://${var.aws_region}.console.aws.amazon.com/emr/home?region=${var.aws_region}#cluster-details:${module.emr.cluster_id}"
    cluster_list    = "https://${var.aws_region}.console.aws.amazon.com/emr/home?region=${var.aws_region}#cluster-list"
    step_details    = "https://${var.aws_region}.console.aws.amazon.com/emr/home?region=${var.aws_region}#step-details:${module.emr.cluster_id}"
  }
}

output "spark_ui_urls" {
  description = "Spark UI URLs (when cluster is running)"
  value = {
    spark_history_server = "http://${module.emr.master_public_dns}:18080"
    spark_ui             = "http://${module.emr.master_public_dns}:4040"
    yarn_resource_manager = "http://${module.emr.master_public_dns}:8088"
    hue_interface        = "http://${module.emr.master_public_dns}:8888"
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
    emr_cluster = {
      master_node = "${var.master_instance_type} - ~$150-300 USD per month"
      core_nodes  = "${var.core_instance_count} x ${var.core_instance_type} - ~$200-400 USD per month"
      task_nodes  = "${var.task_instance_count} x ${var.task_instance_type} - ~$100-200 USD per month (if used)"
    }
    s3_storage = "~$2.30 USD per 100GB"
    redshift   = var.enable_redshift ? "~$180 USD per month (dc2.large)" : "Not enabled"
    airflow    = var.enable_airflow ? "~$100-200 USD per month" : "Not enabled"
    total_estimate = var.enable_redshift && var.enable_airflow ? "~$700-1200 USD per month" : var.enable_redshift ? "~$600-1000 USD per month" : var.enable_airflow ? "~$500-900 USD per month" : "~$400-800 USD per month"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    cloudwatch_dashboard = module.cloudwatch.dashboard_url
    emr_cluster_id      = module.emr.cluster_id
    log_groups          = module.cloudwatch.log_group_names
    spark_ui_url        = "http://${module.emr.master_public_dns}:4040"
    yarn_ui_url         = "http://${module.emr.master_public_dns}:8088"
  }
}

# Access Information
output "access_info" {
  description = "Access information for the EMR cluster"
  value = {
    ssh_command = "ssh -i your-key.pem hadoop@${module.emr.master_public_dns}"
    s3_access   = "s3://${module.s3.bucket_names["raw-data"]}"
    cluster_id  = module.emr.cluster_id
    region      = var.aws_region
  }
}
