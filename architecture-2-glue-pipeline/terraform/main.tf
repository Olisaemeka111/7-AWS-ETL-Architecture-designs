# Architecture 2: AWS Glue ETL Pipeline - Main Terraform Configuration

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
    Architecture = "glue-etl-pipeline"
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
module "s3_data_lake" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Data lake buckets
  buckets = {
    "raw-zone" = {
      name = "${var.project_name}-${var.environment}-raw-zone"
      versioning = true
      lifecycle_rules = [
        {
          id     = "raw_zone_lifecycle"
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
    "clean-zone" = {
      name = "${var.project_name}-${var.environment}-clean-zone"
      versioning = true
      lifecycle_rules = [
        {
          id     = "clean_zone_lifecycle"
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
    "aggregated-zone" = {
      name = "${var.project_name}-${var.environment}-aggregated-zone"
      versioning = true
      lifecycle_rules = [
        {
          id     = "aggregated_zone_lifecycle"
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
    "temp-zone" = {
      name = "${var.project_name}-${var.environment}-temp-zone"
      versioning = false
      lifecycle_rules = [
        {
          id     = "temp_zone_lifecycle"
          status = "Enabled"
          expiration = {
            days = 7
          }
        }
      ]
    }
    "logs-zone" = {
      name = "${var.project_name}-${var.environment}-logs-zone"
      versioning = false
      lifecycle_rules = [
        {
          id     = "logs_zone_lifecycle"
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

# Glue Module
module "glue" {
  source = "./modules/glue"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket references
  raw_zone_bucket      = module.s3_data_lake.bucket_names["raw-zone"]
  clean_zone_bucket    = module.s3_data_lake.bucket_names["clean-zone"]
  aggregated_zone_bucket = module.s3_data_lake.bucket_names["aggregated-zone"]
  temp_zone_bucket     = module.s3_data_lake.bucket_names["temp-zone"]
  logs_zone_bucket     = module.s3_data_lake.bucket_names["logs-zone"]
  
  # VPC configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.vpc.security_group_id]
  
  # Glue job configuration
  glue_jobs = {
    "extract-job" = {
      name         = "${var.project_name}-${var.environment}-extract-job"
      script_path  = "s3://${module.s3_data_lake.bucket_names["logs-zone"]}/scripts/extract_job.py"
      max_capacity = var.extract_job_dpu
      timeout      = 60
      glue_version = "4.0"
    }
    "transform-job" = {
      name         = "${var.project_name}-${var.environment}-transform-job"
      script_path  = "s3://${module.s3_data_lake.bucket_names["logs-zone"]}/scripts/transform_job.py"
      max_capacity = var.transform_job_dpu
      timeout      = 120
      glue_version = "4.0"
    }
    "load-job" = {
      name         = "${var.project_name}-${var.environment}-load-job"
      script_path  = "s3://${module.s3_data_lake.bucket_names["logs-zone"]}/scripts/load_job.py"
      max_capacity = var.load_job_dpu
      timeout      = 90
      glue_version = "4.0"
    }
  }
  
  # Crawler configuration
  crawlers = {
    "source-crawler" = {
      name         = "${var.project_name}-${var.environment}-source-crawler"
      database_name = "${var.project_name}_${var.environment}_source_db"
      s3_targets   = [
        "s3://${module.s3_data_lake.bucket_names["raw-zone"]}/sources/"
      ]
      schedule     = "cron(0 2 * * ? *)"  # Daily at 2 AM
    }
    "clean-crawler" = {
      name         = "${var.project_name}-${var.environment}-clean-crawler"
      database_name = "${var.project_name}_${var.environment}_clean_db"
      s3_targets   = [
        "s3://${module.s3_data_lake.bucket_names["clean-zone"]}/"
      ]
      schedule     = "cron(0 4 * * ? *)"  # Daily at 4 AM
    }
  }
  
  tags = local.common_tags
}

# Redshift Module (Optional - for data warehouse)
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
  cluster_identifier = "${var.project_name}-${var.environment}-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Glue job names for monitoring
  glue_job_names = [
    module.glue.job_names["extract-job"],
    module.glue.job_names["transform-job"],
    module.glue.job_names["load-job"]
  ]
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3_data_lake.bucket_names["raw-zone"],
    module.s3_data_lake.bucket_names["clean-zone"],
    module.s3_data_lake.bucket_names["aggregated-zone"]
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
    module.s3_data_lake.bucket_arns["raw-zone"],
    module.s3_data_lake.bucket_arns["clean-zone"],
    module.s3_data_lake.bucket_arns["aggregated-zone"],
    module.s3_data_lake.bucket_arns["temp-zone"],
    module.s3_data_lake.bucket_arns["logs-zone"]
  ]
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  tags = local.common_tags
}
