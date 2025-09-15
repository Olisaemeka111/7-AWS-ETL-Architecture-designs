# Architecture 1: Serverless ETL with Lambda - Main Terraform Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Architecture = "Serverless-ETL-Lambda"
    ManagedBy   = "Terraform"
  }
  
  lambda_function_name_prefix = "${var.project_name}-${var.environment}"
}

# VPC Configuration (optional - for RDS access)
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  project_name = var.project_name
  vpc_cidr = var.vpc_cidr
  
  tags = local.common_tags
}

# S3 Buckets
module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
  project_name = var.project_name
  
  tags = local.common_tags
}

# RDS Database (source)
module "rds" {
  source = "./modules/rds"
  
  environment = var.environment
  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.rds_security_group_id]
  
  tags = local.common_tags
}

# Redshift Cluster (destination)
module "redshift" {
  source = "./modules/redshift"
  
  environment = var.environment
  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.redshift_security_group_id]
  
  tags = local.common_tags
}

# SQS Queues
module "sqs" {
  source = "./modules/sqs"
  
  environment = var.environment
  project_name = var.project_name
  
  tags = local.common_tags
}

# Lambda Functions
module "lambda" {
  source = "./modules/lambda"
  
  environment = var.environment
  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  
  # Dependencies
  source_rds_endpoint = module.rds.endpoint
  target_redshift_endpoint = module.redshift.endpoint
  staging_bucket_name = module.s3.staging_bucket_name
  processing_queue_url = module.sqs.processing_queue_url
  dlq_url = module.sqs.dlq_url
  
  tags = local.common_tags
}

# EventBridge
module "eventbridge" {
  source = "./modules/eventbridge"
  
  environment = var.environment
  project_name = var.project_name
  
  extract_lambda_arn = module.lambda.extract_lambda_arn
  
  tags = local.common_tags
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"
  
  environment = var.environment
  project_name = var.project_name
  
  # Resource ARNs
  staging_bucket_arn = module.s3.staging_bucket_arn
  source_rds_arn = module.rds.arn
  target_redshift_arn = module.redshift.arn
  processing_queue_arn = module.sqs.processing_queue_arn
  dlq_arn = module.sqs.dlq_arn
  
  tags = local.common_tags
}

# CloudWatch Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  environment = var.environment
  project_name = var.project_name
  
  # Lambda ARNs
  extract_lambda_name = module.lambda.extract_lambda_name
  transform_lambda_name = module.lambda.transform_lambda_name
  load_lambda_name = module.lambda.load_lambda_name
  
  # SQS URLs
  processing_queue_url = module.sqs.processing_queue_url
  dlq_url = module.sqs.dlq_url
  
  # Database endpoints
  redshift_endpoint = module.redshift.endpoint
  
  tags = local.common_tags
}
