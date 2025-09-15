# Architecture 7: Step Functions ETL - Main Terraform Configuration

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
    Architecture = "step-functions-etl"
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

# Lambda Module for ETL Functions
module "lambda" {
  source = "./modules/lambda"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda functions
  functions = {
    "etl-extract" = {
      name         = "${var.project_name}-${var.environment}-etl-extract"
      handler      = "extract.lambda_handler"
      runtime      = "python3.9"
      timeout      = 300
      memory_size  = 1024
      source_path  = "src/lambda/extract.py"
      environment_variables = {
        S3_RAW_BUCKET = module.s3.bucket_names["raw-data"]
        S3_PROCESSED_BUCKET = module.s3.bucket_names["processed-data"]
        AWS_DEFAULT_REGION = var.aws_region
      }
    }
    "etl-transform" = {
      name         = "${var.project_name}-${var.environment}-etl-transform"
      handler      = "transform.lambda_handler"
      runtime      = "python3.9"
      timeout      = 300
      memory_size  = 1024
      source_path  = "src/lambda/transform.py"
      environment_variables = {
        S3_RAW_BUCKET = module.s3.bucket_names["raw-data"]
        S3_PROCESSED_BUCKET = module.s3.bucket_names["processed-data"]
        S3_AGGREGATED_BUCKET = module.s3.bucket_names["aggregated-data"]
        AWS_DEFAULT_REGION = var.aws_region
      }
    }
    "etl-validate" = {
      name         = "${var.project_name}-${var.environment}-etl-validate"
      handler      = "validate.lambda_handler"
      runtime      = "python3.9"
      timeout      = 180
      memory_size  = 512
      source_path  = "src/lambda/validate.py"
      environment_variables = {
        S3_PROCESSED_BUCKET = module.s3.bucket_names["processed-data"]
        AWS_DEFAULT_REGION = var.aws_region
      }
    }
    "etl-load" = {
      name         = "${var.project_name}-${var.environment}-etl-load"
      handler      = "load.lambda_handler"
      runtime      = "python3.9"
      timeout      = 300
      memory_size  = 1024
      source_path  = "src/lambda/load.py"
      environment_variables = {
        S3_PROCESSED_BUCKET = module.s3.bucket_names["processed-data"]
        S3_AGGREGATED_BUCKET = module.s3.bucket_names["aggregated-data"]
        REDSHIFT_ENDPOINT = var.enable_redshift ? module.redshift[0].cluster_endpoint : ""
        AWS_DEFAULT_REGION = var.aws_region
      }
    }
    "etl-error-handler" = {
      name         = "${var.project_name}-${var.environment}-etl-error-handler"
      handler      = "error_handler.lambda_handler"
      runtime      = "python3.9"
      timeout      = 60
      memory_size  = 256
      source_path  = "src/lambda/error_handler.py"
      environment_variables = {
        SNS_TOPIC_ARN = module.sns.topic_arns["etl-alerts"]
        AWS_DEFAULT_REGION = var.aws_region
      }
    }
  }
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # IAM role for Lambda execution
  iam_role_arn       = module.iam.lambda_execution_role_arn
  
  tags = local.common_tags
}

# Glue Module for ETL Jobs
module "glue" {
  source = "./modules/glue"
  
  project_name = var.project_name
  environment  = var.environment
  
  # IAM role for Glue execution
  iam_role_arn          = module.iam.glue_service_role_arn
  
  # Glue jobs
  glue_jobs = {
    "etl-transform-job" = {
      name         = "${var.project_name}-${var.environment}-etl-transform-job"
      script_path  = "s3://${module.s3.bucket_names["logs"]}/scripts/transform_job.py"
      max_capacity = var.glue_max_capacity
      timeout      = var.glue_timeout
      glue_version = var.glue_version
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

# EMR Module (Optional)
module "emr" {
  count = var.enable_emr ? 1 : 0
  
  source = "./modules/emr"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # EMR configuration
  cluster_name = "${var.project_name}-${var.environment}-etl-cluster"
  release_label = var.emr_release_label
  applications = var.emr_applications
  
  # Instance configuration
  master_instance_type = var.emr_master_instance_type
  core_instance_type   = var.emr_core_instance_type
  core_instance_count  = var.emr_core_instance_count
  
  # S3 bucket references
  logs_bucket = module.s3.bucket_names["logs"]
  
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
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Redshift configuration
  cluster_identifier = "${var.project_name}-${var.environment}-step-functions-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# SNS Module for Notifications
module "sns" {
  source = "./modules/sns"
  
  project_name = var.project_name
  environment  = var.environment
  
  # SNS topics
  topics = {
    "etl-alerts" = {
      name = "${var.project_name}-${var.environment}-etl-alerts"
      display_name = "ETL Pipeline Alerts"
      subscriptions = [
        {
          protocol = "email"
          endpoint  = var.alert_email
        }
      ]
    }
    "etl-notifications" = {
      name = "${var.project_name}-${var.environment}-etl-notifications"
      display_name = "ETL Pipeline Notifications"
      subscriptions = [
        {
          protocol = "email"
          endpoint  = var.notification_email
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# Step Functions Module
module "step_functions" {
  source = "./modules/step_functions"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Step Functions state machine
  state_machine = {
    name = "${var.project_name}-${var.environment}-etl-state-machine"
    definition = jsonencode({
      Comment = "ETL Pipeline State Machine"
      StartAt = "ExtractData"
      States = {
        ExtractData = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-extract"]
          Next = "TransformData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
          Catch = [
            {
              ErrorEquals = ["States.ALL"]
              Next = "HandleExtractError"
              ResultPath = "$.error"
            }
          ]
        }
        TransformData = {
          Type = "Task"
          Resource = var.enable_emr ? "arn:aws:states:::emr:addStep.sync" : "arn:aws:states:::glue:startJobRun.sync"
          Parameters = var.enable_emr ? {
            ClusterId = module.emr[0].cluster_id
            Step = {
              Name = "Transform Step"
              ActionOnFailure = "CONTINUE"
              HadoopJarStep = {
                Jar = "command-runner.jar"
                Args = ["spark-submit", "--deploy-mode", "cluster", "s3://${module.s3.bucket_names["logs"]}/scripts/transform_job.py"]
              }
            }
          } : {
            JobName = module.glue.job_names["etl-transform-job"]
            Arguments = {
              "--raw_data_bucket" = module.s3.bucket_names["raw-data"]
              "--processed_data_bucket" = module.s3.bucket_names["processed-data"]
            }
          }
          Next = "ValidateData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 5
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
          Catch = [
            {
              ErrorEquals = ["States.ALL"]
              Next = "HandleTransformError"
              ResultPath = "$.error"
            }
          ]
        }
        ValidateData = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-validate"]
          Next = "LoadData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
          Catch = [
            {
              ErrorEquals = ["States.ALL"]
              Next = "HandleValidationError"
              ResultPath = "$.error"
            }
          ]
        }
        LoadData = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-load"]
          End = true
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
          Catch = [
            {
              ErrorEquals = ["States.ALL"]
              Next = "HandleLoadError"
              ResultPath = "$.error"
            }
          ]
        }
        HandleExtractError = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-error-handler"]
          Next = "ExtractData"
          Parameters = {
            error = "$.error"
            retry_count = "$.retry_count"
            state_name = "ExtractData"
          }
        }
        HandleTransformError = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-error-handler"]
          Next = "TransformData"
          Parameters = {
            error = "$.error"
            retry_count = "$.retry_count"
            state_name = "TransformData"
          }
        }
        HandleValidationError = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-error-handler"]
          Next = "ValidateData"
          Parameters = {
            error = "$.error"
            retry_count = "$.retry_count"
            state_name = "ValidateData"
          }
        }
        HandleLoadError = {
          Type = "Task"
          Resource = module.lambda.function_arns["etl-error-handler"]
          Next = "LoadData"
          Parameters = {
            error = "$.error"
            retry_count = "$.retry_count"
            state_name = "LoadData"
          }
        }
      }
    })
  }
  
  # IAM role for Step Functions
  execution_role_arn = module.iam.step_functions_execution_role_arn
  
  tags = local.common_tags
}

# EventBridge Module for Scheduling
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
          arn = module.step_functions.state_machine_arn
          id  = "ETLStateMachineTarget"
          role_arn = module.iam.eventbridge_step_functions_role_arn
        }
      ]
    }
    "etl-monitoring" = {
      name                = "${var.project_name}-${var.environment}-etl-monitoring"
      description         = "Monitor ETL pipeline health"
      schedule_expression = "rate(5 minutes)"
      targets = [
        {
          arn = module.lambda.function_arns["etl-error-handler"]
          id  = "ETLMonitoringTarget"
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
  
  # Lambda function names for monitoring
  lambda_function_names = [
    module.lambda.function_names["etl-extract"],
    module.lambda.function_names["etl-transform"],
    module.lambda.function_names["etl-validate"],
    module.lambda.function_names["etl-load"],
    module.lambda.function_names["etl-error-handler"]
  ]
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3.bucket_names["raw-data"],
    module.s3.bucket_names["processed-data"],
    module.s3.bucket_names["aggregated-data"]
  ]
  
  # Glue job names for monitoring
  glue_job_names = [
    module.glue.job_names["etl-transform-job"]
  ]
  
  # EMR cluster ID for monitoring (if enabled)
  emr_cluster_id = var.enable_emr ? module.emr[0].cluster_id : null
  
  # Redshift cluster identifier (if enabled)
  redshift_cluster_identifier = var.enable_redshift ? module.redshift[0].cluster_identifier : null
  
  # Step Functions state machine ARN
  step_functions_state_machine_arn = module.step_functions.state_machine_arn
  
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
  
  # Lambda function ARNs
  lambda_function_arns = [
    module.lambda.function_arns["etl-extract"],
    module.lambda.function_arns["etl-transform"],
    module.lambda.function_arns["etl-validate"],
    module.lambda.function_arns["etl-load"],
    module.lambda.function_arns["etl-error-handler"]
  ]
  
  # Glue job ARNs
  glue_job_arns = [
    module.glue.job_arns["etl-transform-job"]
  ]
  
  # EMR cluster ARN (if enabled)
  emr_cluster_arn = var.enable_emr ? module.emr[0].cluster_arn : null
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  # Step Functions state machine ARN
  step_functions_state_machine_arn = module.step_functions.state_machine_arn
  
  # SNS topic ARNs
  sns_topic_arns = [
    module.sns.topic_arns["etl-alerts"],
    module.sns.topic_arns["etl-notifications"]
  ]
  
  tags = local.common_tags
}
