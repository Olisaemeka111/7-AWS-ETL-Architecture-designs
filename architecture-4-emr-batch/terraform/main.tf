# Architecture 4: EMR Batch ETL - Main Terraform Configuration

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
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Architecture = "emr-batch-etl"
  }
  
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  
  tags = local.common_tags
}

# S3 Module for Data Lake
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Data lake buckets
  buckets = {
    "raw-data" = {
      name = "${var.project_name}-${var.environment}-raw-data"
      versioning = true
      lifecycle_rules = [
        {
          id     = "raw_data_lifecycle"
          status = "Enabled"
          transitions = [
            {
              days          = 30
              storage_class = "STANDARD_IA"
            },
            {
              days          = 90
              storage_class = "GLACIER"
            }
          ]
        }
      ]
    }
    "processed-data" = {
      name = "${var.project_name}-${var.environment}-processed-data"
      versioning = true
      lifecycle_rules = [
        {
          id     = "processed_data_lifecycle"
          status = "Enabled"
          transitions = [
            {
              days          = 60
              storage_class = "STANDARD_IA"
            },
            {
              days          = 180
              storage_class = "GLACIER"
            }
          ]
        }
      ]
    }
    "aggregated-data" = {
      name = "${var.project_name}-${var.environment}-aggregated-data"
      versioning = true
      lifecycle_rules = [
        {
          id     = "aggregated_data_lifecycle"
          status = "Enabled"
          transitions = [
            {
              days          = 90
              storage_class = "STANDARD_IA"
            },
            {
              days          = 365
              storage_class = "GLACIER"
            }
          ]
        }
      ]
    }
    "logs" = {
      name = "${var.project_name}-${var.environment}-logs"
      versioning = false
      lifecycle_rules = [
        {
          id     = "logs_lifecycle"
          status = "Enabled"
          transitions = [
            {
              days          = 30
              storage_class = "STANDARD_IA"
            },
            {
              days          = 90
              storage_class = "GLACIER"
            }
          ]
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# EMR Module
module "emr" {
  source = "./modules/emr"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket references
  raw_data_bucket      = module.s3.bucket_names["raw-data"]
  processed_data_bucket = module.s3.bucket_names["processed-data"]
  aggregated_data_bucket = module.s3.bucket_names["aggregated-data"]
  logs_bucket          = module.s3.bucket_names["logs"]
  
  # VPC configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.vpc.security_group_id]
  
  # EMR cluster configuration
  cluster_name = "${var.project_name}-${var.environment}-etl-cluster"
  
  # Instance configuration
  master_instance_type = var.master_instance_type
  core_instance_type   = var.core_instance_type
  core_instance_count  = var.core_instance_count
  task_instance_type   = var.task_instance_type
  task_instance_count  = var.task_instance_count
  
  # Auto-scaling configuration
  enable_auto_scaling = var.enable_auto_scaling
  min_capacity        = var.min_capacity
  max_capacity        = var.max_capacity
  
  # Spot instance configuration
  enable_spot_instances = var.enable_spot_instances
  spot_bid_price        = var.spot_bid_price
  
  # Applications
  applications = var.emr_applications
  
  # Bootstrap actions
  bootstrap_actions = var.bootstrap_actions
  
  # Steps
  steps = var.emr_steps
  
  tags = local.common_tags
}

# Glue Module for Data Catalog
module "glue" {
  source = "./modules/glue"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket references
  raw_data_bucket      = module.s3.bucket_names["raw-data"]
  processed_data_bucket = module.s3.bucket_names["processed-data"]
  aggregated_data_bucket = module.s3.bucket_names["aggregated-data"]
  
  # VPC configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.vpc.security_group_id]
  
  # Glue configuration
  glue_jobs = {
    "data-catalog-job" = {
      name         = "${var.project_name}-${var.environment}-data-catalog-job"
      script_path  = "s3://${module.s3.bucket_names["logs"]}/scripts/data_catalog_job.py"
      max_capacity = 2
      timeout      = 60
      glue_version = "4.0"
    }
  }
  
  # Crawler configuration
  crawlers = {
    "raw-data-crawler" = {
      name          = "${var.project_name}-${var.environment}-raw-data-crawler"
      database_name = "${var.project_name}_${var.environment}_raw_db"
      s3_targets    = [
        "s3://${module.s3.bucket_names["raw-data"]}/"
      ]
      schedule      = "cron(0 2 * * ? *)"  # Daily at 2 AM
    }
    "processed-data-crawler" = {
      name          = "${var.project_name}-${var.environment}-processed-data-crawler"
      database_name = "${var.project_name}_${var.environment}_processed_db"
      s3_targets    = [
        "s3://${module.s3.bucket_names["processed-data"]}/"
      ]
      schedule      = "cron(0 4 * * ? *)"  # Daily at 4 AM
    }
  }
  
  tags = local.common_tags
}

# Redshift Module (Optional)
module "redshift" {
  count = var.enable_redshift ? 1 : 0
  
  source = "./modules/redshift"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Redshift configuration
  cluster_identifier = "${var.project_name}-${var.environment}-batch-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# Airflow Module (Optional)
module "airflow" {
  count = var.enable_airflow ? 1 : 0
  
  source = "./modules/airflow"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Airflow configuration
  airflow_environment_name = "${var.project_name}-${var.environment}-airflow"
  airflow_version          = var.airflow_version
  instance_type            = var.airflow_instance_type
  min_workers              = var.airflow_min_workers
  max_workers              = var.airflow_max_workers
  
  # EMR cluster reference
  emr_cluster_id = module.emr.cluster_id
  
  tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # EMR cluster ID for monitoring
  emr_cluster_id = module.emr.cluster_id
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3.bucket_names["raw-data"],
    module.s3.bucket_names["processed-data"],
    module.s3.bucket_names["aggregated-data"]
  ]
  
  # Redshift cluster identifier (if enabled)
  redshift_cluster_identifier = var.enable_redshift ? module.redshift[0].cluster_identifier : null
  
  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket ARNs
  s3_bucket_arns = [
    module.s3.bucket_arns["raw-data"],
    module.s3.bucket_arns["processed-data"],
    module.s3.bucket_arns["aggregated-data"],
    module.s3.bucket_arns["logs"]
  ]
  
  # EMR cluster ARN
  emr_cluster_arn = module.emr.cluster_arn
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  tags = local.common_tags
}
