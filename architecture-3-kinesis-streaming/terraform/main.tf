# Architecture 3: Kinesis Streaming ETL - Main Terraform Configuration

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
    Architecture = "kinesis-streaming-etl"
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

# S3 Module for Data Storage
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Data storage buckets
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

# Kinesis Module
module "kinesis" {
  source = "./modules/kinesis"
  
  project_name = var.project_name
  environment  = var.environment
  
  # S3 bucket references
  raw_data_bucket      = module.s3.bucket_names["raw-data"]
  processed_data_bucket = module.s3.bucket_names["processed-data"]
  logs_bucket          = module.s3.bucket_names["logs"]
  
  # Kinesis configuration
  kinesis_streams = {
    "main-stream" = {
      name             = "${var.project_name}-${var.environment}-main-stream"
      shard_count      = var.kinesis_shard_count
      retention_period = var.kinesis_retention_period
      encryption_type  = var.kinesis_encryption_type
    }
    "analytics-stream" = {
      name             = "${var.project_name}-${var.environment}-analytics-stream"
      shard_count      = var.analytics_shard_count
      retention_period = var.kinesis_retention_period
      encryption_type  = var.kinesis_encryption_type
    }
  }
  
  # Kinesis Analytics configuration
  kinesis_analytics = {
    "stream-processor" = {
      name         = "${var.project_name}-${var.environment}-stream-processor"
      runtime      = "SQL-1_0"
      inputs       = ["main-stream"]
      outputs      = ["analytics-stream"]
      sql_code     = var.kinesis_analytics_sql
    }
  }
  
  # Kinesis Data Firehose configuration
  firehose_delivery_streams = {
    "s3-delivery" = {
      name        = "${var.project_name}-${var.environment}-s3-delivery"
      destination = "s3"
      s3_bucket   = module.s3.bucket_names["raw-data"]
      prefix      = "streaming-data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    }
    "redshift-delivery" = {
      name           = "${var.project_name}-${var.environment}-redshift-delivery"
      destination    = "redshift"
      s3_bucket      = module.s3.bucket_names["processed-data"]
      redshift_cluster = var.enable_redshift ? module.redshift[0].cluster_endpoint : null
      redshift_database = var.redshift_database_name
      redshift_table   = var.redshift_table_name
    }
  }
  
  tags = local.common_tags
}

# Lambda Module for Stream Processing
module "lambda" {
  source = "./modules/lambda"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids    = [module.vpc.security_group_id]
  
  # Lambda functions
  lambda_functions = {
    "stream-processor" = {
      name         = "${var.project_name}-${var.environment}-stream-processor"
      handler      = "stream_processor.lambda_handler"
      runtime      = "python3.9"
      timeout      = 60
      memory_size  = 512
      environment_variables = {
        KINESIS_STREAM_NAME = module.kinesis.stream_names["main-stream"]
        S3_BUCKET          = module.s3.bucket_names["processed-data"]
      }
    }
    "data-enricher" = {
      name         = "${var.project_name}-${var.environment}-data-enricher"
      handler      = "data_enricher.lambda_handler"
      runtime      = "python3.9"
      timeout      = 30
      memory_size  = 256
      environment_variables = {
        ENRICHMENT_TABLE = var.enrichment_table_name
      }
    }
    "anomaly-detector" = {
      name         = "${var.project_name}-${var.environment}-anomaly-detector"
      handler      = "anomaly_detector.lambda_handler"
      runtime      = "python3.9"
      timeout      = 45
      memory_size  = 512
      environment_variables = {
        ALERT_TOPIC_ARN = module.sns.sns_topic_arn
      }
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
  cluster_identifier = "${var.project_name}-${var.environment}-streaming-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# OpenSearch Module
module "opensearch" {
  source = "./modules/opensearch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # OpenSearch configuration
  domain_name = "${var.project_name}-${var.environment}-streaming-search"
  instance_type = var.opensearch_instance_type
  instance_count = var.opensearch_instance_count
  
  tags = local.common_tags
}

# SNS Module for Alerting
module "sns" {
  source = "./modules/sns"
  
  project_name = var.project_name
  environment  = var.environment
  
  # SNS topics
  topics = {
    "alerts" = {
      name = "${var.project_name}-${var.environment}-alerts"
      subscribers = var.alert_emails
    }
    "notifications" = {
      name = "${var.project_name}-${var.environment}-notifications"
      subscribers = var.notification_emails
    }
  }
  
  tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Kinesis stream names for monitoring
  kinesis_stream_names = [
    module.kinesis.stream_names["main-stream"],
    module.kinesis.stream_names["analytics-stream"]
  ]
  
  # Lambda function names for monitoring
  lambda_function_names = [
    module.lambda.function_names["stream-processor"],
    module.lambda.function_names["data-enricher"],
    module.lambda.function_names["anomaly-detector"]
  ]
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3.bucket_names["raw-data"],
    module.s3.bucket_names["processed-data"]
  ]
  
  # OpenSearch domain name for monitoring
  opensearch_domain_name = module.opensearch.domain_name
  
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
  
  # Kinesis stream ARNs
  kinesis_stream_arns = [
    module.kinesis.stream_arns["main-stream"],
    module.kinesis.stream_arns["analytics-stream"]
  ]
  
  # Lambda function ARNs
  lambda_function_arns = [
    module.lambda.function_arns["stream-processor"],
    module.lambda.function_arns["data-enricher"],
    module.lambda.function_arns["anomaly-detector"]
  ]
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  # OpenSearch domain ARN
  opensearch_domain_arn = module.opensearch.domain_arn
  
  tags = local.common_tags
}
