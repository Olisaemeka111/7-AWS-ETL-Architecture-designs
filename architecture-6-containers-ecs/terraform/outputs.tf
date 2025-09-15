# Architecture 6: Containerized ETL with ECS - Outputs

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

# ECR Outputs
output "ecr_repository_uris" {
  description = "URIs of the ECR repositories"
  value       = module.ecr.repository_uris
}

output "ecr_repository_arns" {
  description = "ARNs of the ECR repositories"
  value       = module.ecr.repository_arns
}

output "etl_extract_repository_uri" {
  description = "URI of the ETL extract repository"
  value       = module.ecr.repository_uris["etl-extract"]
}

output "etl_transform_repository_uri" {
  description = "URI of the ETL transform repository"
  value       = module.ecr.repository_uris["etl-transform"]
}

output "etl_load_repository_uri" {
  description = "URI of the ETL load repository"
  value       = module.ecr.repository_uris["etl-load"]
}

output "etl_validation_repository_uri" {
  description = "URI of the ETL validation repository"
  value       = module.ecr.repository_uris["etl-validation"]
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_names" {
  description = "Names of the ECS services"
  value       = module.ecs.service_names
}

output "ecs_service_arns" {
  description = "ARNs of the ECS services"
  value       = module.ecs.service_arns
}

output "ecs_task_definition_arns" {
  description = "ARNs of the ECS task definitions"
  value       = module.ecs.task_definition_arns
}

output "etl_extract_service_name" {
  description = "Name of the ETL extract service"
  value       = module.ecs.service_names["etl-extract-service"]
}

output "etl_transform_service_name" {
  description = "Name of the ETL transform service"
  value       = module.ecs.service_names["etl-transform-service"]
}

output "etl_load_service_name" {
  description = "Name of the ETL load service"
  value       = module.ecs.service_names["etl-load-service"]
}

output "etl_validation_service_name" {
  description = "Name of the ETL validation service"
  value       = module.ecs.service_names["etl-validation-service"]
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
output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = module.iam.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

output "step_functions_execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = module.iam.step_functions_execution_role_arn
}

output "eventbridge_step_functions_role_arn" {
  description = "ARN of the EventBridge Step Functions role"
  value       = module.iam.eventbridge_step_functions_role_arn
}

# Container Information
output "container_registry_info" {
  description = "Container registry information"
  value = {
    extract_repository = {
      uri = module.ecr.repository_uris["etl-extract"]
      arn = module.ecr.repository_arns["etl-extract"]
    }
    transform_repository = {
      uri = module.ecr.repository_uris["etl-transform"]
      arn = module.ecr.repository_arns["etl-transform"]
    }
    load_repository = {
      uri = module.ecr.repository_uris["etl-load"]
      arn = module.ecr.repository_arns["etl-load"]
    }
    validation_repository = {
      uri = module.ecr.repository_uris["etl-validation"]
      arn = module.ecr.repository_arns["etl-validation"]
    }
  }
}

# ECS Console URLs
output "ecs_console_urls" {
  description = "AWS ECS console URLs"
  value = {
    cluster_details = "https://${var.aws_region}.console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${module.ecs.cluster_id}"
    services_list   = "https://${var.aws_region}.console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${module.ecs.cluster_id}/services"
    task_definitions = "https://${var.aws_region}.console.aws.amazon.com/ecs/home?region=${var.aws_region}#/taskDefinitions"
  }
}

# Step Functions Console URLs
output "step_functions_console_urls" {
  description = "AWS Step Functions console URLs"
  value = {
    state_machine_details = "https://${var.aws_region}.console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${module.step_functions.state_machine_arn}"
    executions_list      = "https://${var.aws_region}.console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${module.step_functions.state_machine_arn}/executions"
  }
}

# ECR Console URLs
output "ecr_console_urls" {
  description = "AWS ECR console URLs"
  value = {
    repositories_list = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories?region=${var.aws_region}"
    extract_repository = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories/private/${local.account_id}/${module.ecr.repository_uris["etl-extract"]}?region=${var.aws_region}"
    transform_repository = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories/private/${local.account_id}/${module.ecr.repository_uris["etl-transform"]}?region=${var.aws_region}"
    load_repository = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories/private/${local.account_id}/${module.ecr.repository_uris["etl-load"]}?region=${var.aws_region}"
    validation_repository = "https://${var.aws_region}.console.aws.amazon.com/ecr/repositories/private/${local.account_id}/${module.ecr.repository_uris["etl-validation"]}?region=${var.aws_region}"
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
    ecs_launch_type = var.ecs_launch_type
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    ecs_cluster = {
      launch_type = var.ecs_launch_type
      estimated_cost = var.ecs_launch_type == "FARGATE" ? "~$50-200 USD per month" : "~$30-150 USD per month"
    }
    ecr_storage = "~$0.10 USD per GB per month"
    s3_storage = "~$2.30 USD per 100GB"
    step_functions = "~$0.025 USD per 1000 state transitions"
    redshift = var.enable_redshift ? "~$180 USD per month (dc2.large)" : "Not enabled"
    total_estimate = var.enable_redshift ? "~$250-450 USD per month" : "~$80-250 USD per month"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    cloudwatch_dashboard = module.cloudwatch.dashboard_url
    ecs_cluster_id     = module.ecs.cluster_id
    step_functions_arn = module.step_functions.state_machine_arn
    log_groups         = module.cloudwatch.log_group_names
  }
}

# Access Information
output "access_info" {
  description = "Access information for the ECS cluster"
  value = {
    ecs_cluster_name = module.ecs.cluster_name
    ecs_cluster_id   = module.ecs.cluster_id
    region          = var.aws_region
    s3_buckets      = module.s3.bucket_names
    redshift_endpoint = var.enable_redshift ? module.redshift[0].cluster_endpoint : null
  }
}

# Container Deployment Commands
output "container_deployment_commands" {
  description = "Commands for deploying container images"
  value = {
    aws_login = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    extract_build = "docker build -t ${module.ecr.repository_uris["etl-extract"]}:latest ./src/containers/extract/"
    extract_push = "docker push ${module.ecr.repository_uris["etl-extract"]}:latest"
    transform_build = "docker build -t ${module.ecr.repository_uris["etl-transform"]}:latest ./src/containers/transform/"
    transform_push = "docker push ${module.ecr.repository_uris["etl-transform"]}:latest"
    load_build = "docker build -t ${module.ecr.repository_uris["etl-load"]}:latest ./src/containers/load/"
    load_push = "docker push ${module.ecr.repository_uris["etl-load"]}:latest"
    validation_build = "docker build -t ${module.ecr.repository_uris["etl-validation"]}:latest ./src/containers/validation/"
    validation_push = "docker push ${module.ecr.repository_uris["etl-validation"]}:latest"
  }
}
