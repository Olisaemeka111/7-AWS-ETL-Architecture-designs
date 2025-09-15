# Architecture 5: RDS Database ETL - Main Terraform Configuration

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
    Architecture = "rds-database-etl"
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

# RDS Module - Source Database
module "rds_source" {
  source = "./modules/rds"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Database configuration
  db_identifier = "${var.project_name}-${var.environment}-source-db"
  db_name       = var.source_db_name
  db_username   = var.source_db_username
  db_password   = var.source_db_password
  
  # Instance configuration
  instance_class    = var.source_instance_class
  allocated_storage = var.source_allocated_storage
  max_allocated_storage = var.source_max_allocated_storage
  storage_type      = var.source_storage_type
  storage_encrypted = var.source_storage_encrypted
  
  # Engine configuration
  engine         = var.source_engine
  engine_version = var.source_engine_version
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Backup configuration
  backup_retention_period = var.source_backup_retention_period
  backup_window          = var.source_backup_window
  maintenance_window     = var.source_maintenance_window
  
  # Monitoring
  monitoring_interval = var.source_monitoring_interval
  monitoring_role_arn = var.source_monitoring_role_arn
  
  # Security
  deletion_protection = var.source_deletion_protection
  skip_final_snapshot = var.source_skip_final_snapshot
  
  tags = local.common_tags
}

# RDS Module - Target Database
module "rds_target" {
  source = "./modules/rds"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Database configuration
  db_identifier = "${var.project_name}-${var.environment}-target-db"
  db_name       = var.target_db_name
  db_username   = var.target_db_username
  db_password   = var.target_db_password
  
  # Instance configuration
  instance_class    = var.target_instance_class
  allocated_storage = var.target_allocated_storage
  max_allocated_storage = var.target_max_allocated_storage
  storage_type      = var.target_storage_type
  storage_encrypted = var.target_storage_encrypted
  
  # Engine configuration
  engine         = var.target_engine
  engine_version = var.target_engine_version
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Backup configuration
  backup_retention_period = var.target_backup_retention_period
  backup_window          = var.target_backup_window
  maintenance_window     = var.target_maintenance_window
  
  # Monitoring
  monitoring_interval = var.target_monitoring_interval
  monitoring_role_arn = var.target_monitoring_role_arn
  
  # Security
  deletion_protection = var.target_deletion_protection
  skip_final_snapshot = var.target_skip_final_snapshot
  
  tags = local.common_tags
}

# Aurora Module (Optional)
module "aurora" {
  count = var.enable_aurora ? 1 : 0
  
  source = "./modules/aurora"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Cluster configuration
  cluster_identifier = "${var.project_name}-${var.environment}-aurora-cluster"
  database_name      = var.aurora_database_name
  master_username    = var.aurora_master_username
  master_password    = var.aurora_master_password
  
  # Engine configuration
  engine         = var.aurora_engine
  engine_version = var.aurora_engine_version
  
  # Instance configuration
  instance_class = var.aurora_instance_class
  instance_count = var.aurora_instance_count
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Backup configuration
  backup_retention_period = var.aurora_backup_retention_period
  backup_window          = var.aurora_backup_window
  maintenance_window     = var.aurora_maintenance_window
  
  # Security
  deletion_protection = var.aurora_deletion_protection
  skip_final_snapshot = var.aurora_skip_final_snapshot
  
  tags = local.common_tags
}

# DMS Module
module "dms" {
  source = "./modules/dms"
  
  project_name = var.project_name
  environment  = var.environment
  
  # DMS configuration
  replication_instance_identifier = "${var.project_name}-${var.environment}-dms-instance"
  replication_instance_class      = var.dms_instance_class
  allocated_storage               = var.dms_allocated_storage
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # Source and target endpoints
  source_endpoint = {
    endpoint_id   = "${var.project_name}-${var.environment}-source-endpoint"
    endpoint_type = "source"
    engine_name   = var.source_engine
    server_name   = module.rds_source.endpoint
    port          = var.source_port
    username      = var.source_db_username
    password      = var.source_db_password
    database_name = var.source_db_name
  }
  
  target_endpoint = {
    endpoint_id   = "${var.project_name}-${var.environment}-target-endpoint"
    endpoint_type = "target"
    engine_name   = var.target_engine
    server_name   = module.rds_target.endpoint
    port          = var.target_port
    username      = var.target_db_username
    password      = var.target_db_password
    database_name = var.target_db_name
  }
  
  # Replication tasks
  replication_tasks = var.dms_replication_tasks
  
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

# Lambda Module for ETL Functions
module "lambda" {
  source = "./modules/lambda"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda functions
  functions = {
    "etl-processor" = {
      name         = "${var.project_name}-${var.environment}-etl-processor"
      handler      = "etl_processor.lambda_handler"
      runtime      = "python3.9"
      timeout      = 300
      memory_size  = 512
      source_path  = "src/lambda/etl_processor.py"
      environment_variables = {
        SOURCE_DB_HOST     = module.rds_source.endpoint
        SOURCE_DB_NAME     = var.source_db_name
        SOURCE_DB_USERNAME = var.source_db_username
        TARGET_DB_HOST     = module.rds_target.endpoint
        TARGET_DB_NAME     = var.target_db_name
        TARGET_DB_USERNAME = var.target_db_username
        S3_BUCKET         = module.s3.bucket_names["processed-data"]
      }
    }
    "data-validator" = {
      name         = "${var.project_name}-${var.environment}-data-validator"
      handler      = "data_validator.lambda_handler"
      runtime      = "python3.9"
      timeout      = 180
      memory_size  = 256
      source_path  = "src/lambda/data_validator.py"
      environment_variables = {
        TARGET_DB_HOST     = module.rds_target.endpoint
        TARGET_DB_NAME     = var.target_db_name
        TARGET_DB_USERNAME = var.target_db_username
      }
    }
  }
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  tags = local.common_tags
}

# Glue Module for ETL Jobs
module "glue" {
  source = "./modules/glue"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket references
  raw_data_bucket      = module.s3.bucket_names["raw-data"]
  processed_data_bucket = module.s3.bucket_names["processed-data"]
  logs_bucket          = module.s3.bucket_names["logs"]
  
  # VPC configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.vpc.security_group_id]
  
  # Glue jobs
  glue_jobs = {
    "database-etl-job" = {
      name         = "${var.project_name}-${var.environment}-database-etl-job"
      script_path  = "s3://${module.s3.bucket_names["logs"]}/scripts/database_etl_job.py"
      max_capacity = 2
      timeout      = 60
      glue_version = "4.0"
    }
  }
  
  # Crawler configuration
  crawlers = {
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
  cluster_identifier = "${var.project_name}-${var.environment}-database-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# EventBridge Module for Orchestration
module "eventbridge" {
  source = "./modules/eventbridge"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Event rules
  rules = {
    "etl-schedule" = {
      name                = "${var.project_name}-${var.environment}-etl-schedule"
      description         = "Schedule ETL jobs"
      schedule_expression = var.etl_schedule_expression
      targets = [
        {
          arn = module.lambda.function_arns["etl-processor"]
          id  = "ETLProcessorTarget"
        }
      ]
    }
    "dms-monitoring" = {
      name                = "${var.project_name}-${var.environment}-dms-monitoring"
      description         = "Monitor DMS replication tasks"
      event_pattern = jsonencode({
        source      = ["aws.dms"]
        detail-type = ["DMS Replication Task State Change"]
      })
      targets = [
        {
          arn = module.lambda.function_arns["data-validator"]
          id  = "DataValidatorTarget"
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # RDS cluster IDs for monitoring
  rds_source_id = module.rds_source.db_instance_id
  rds_target_id = module.rds_target.db_instance_id
  
  # DMS replication instance ID
  dms_instance_id = module.dms.replication_instance_id
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3.bucket_names["raw-data"],
    module.s3.bucket_names["processed-data"]
  ]
  
  # Lambda function names for monitoring
  lambda_function_names = [
    module.lambda.function_names["etl-processor"],
    module.lambda.function_names["data-validator"]
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
    module.s3.bucket_arns["logs"]
  ]
  
  # RDS instance ARNs
  rds_source_arn = module.rds_source.db_instance_arn
  rds_target_arn = module.rds_target.db_instance_arn
  
  # DMS replication instance ARN
  dms_instance_arn = module.dms.replication_instance_arn
  
  # Lambda function ARNs
  lambda_function_arns = [
    module.lambda.function_arns["etl-processor"],
    module.lambda.function_arns["data-validator"]
  ]
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  tags = local.common_tags
}
