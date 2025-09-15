# Architecture 6: Containerized ETL with ECS - Main Terraform Configuration

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
    Architecture = "containerized-ecs-etl"
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

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
  environment  = var.environment
  
  # ECR repositories
  repositories = {
    "etl-extract" = {
      name                 = "${var.project_name}-${var.environment}-etl-extract"
      image_tag_mutability = "MUTABLE"
      scan_on_push        = true
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["v"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
    "etl-transform" = {
      name                 = "${var.project_name}-${var.environment}-etl-transform"
      image_tag_mutability = "MUTABLE"
      scan_on_push        = true
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["v"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
    "etl-load" = {
      name                 = "${var.project_name}-${var.environment}-etl-load"
      image_tag_mutability = "MUTABLE"
      scan_on_push        = true
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["v"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
    "etl-validation" = {
      name                 = "${var.project_name}-${var.environment}-etl-validation"
      image_tag_mutability = "MUTABLE"
      scan_on_push        = true
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["v"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
  }
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name = var.project_name
  environment  = var.environment
  
  # VPC configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  
  # ECS cluster configuration
  cluster_name = "${var.project_name}-${var.environment}-etl-cluster"
  
  # Cluster configuration
  cluster_configuration = {
    capacity_providers = var.ecs_capacity_providers
    default_capacity_provider_strategy = var.ecs_default_capacity_provider_strategy
    container_insights = var.ecs_container_insights
  }
  
  # ECS services
  services = {
    "etl-extract-service" = {
      name            = "${var.project_name}-${var.environment}-etl-extract-service"
      task_definition = "etl-extract-task"
      desired_count   = var.extract_service_desired_count
      launch_type     = var.ecs_launch_type
      capacity_provider_strategy = var.ecs_launch_type == "FARGATE" ? null : [
        {
          capacity_provider = "FARGATE"
          weight           = 1
          base             = 0
        }
      ]
      auto_scaling = {
        min_capacity = var.extract_service_min_capacity
        max_capacity = var.extract_service_max_capacity
        target_cpu   = var.extract_service_target_cpu
        target_memory = var.extract_service_target_memory
      }
    }
    "etl-transform-service" = {
      name            = "${var.project_name}-${var.environment}-etl-transform-service"
      task_definition = "etl-transform-task"
      desired_count   = var.transform_service_desired_count
      launch_type     = var.ecs_launch_type
      capacity_provider_strategy = var.ecs_launch_type == "FARGATE" ? null : [
        {
          capacity_provider = "FARGATE"
          weight           = 1
          base             = 0
        }
      ]
      auto_scaling = {
        min_capacity = var.transform_service_min_capacity
        max_capacity = var.transform_service_max_capacity
        target_cpu   = var.transform_service_target_cpu
        target_memory = var.transform_service_target_memory
      }
    }
    "etl-load-service" = {
      name            = "${var.project_name}-${var.environment}-etl-load-service"
      task_definition = "etl-load-task"
      desired_count   = var.load_service_desired_count
      launch_type     = var.ecs_launch_type
      capacity_provider_strategy = var.ecs_launch_type == "FARGATE" ? null : [
        {
          capacity_provider = "FARGATE"
          weight           = 1
          base             = 0
        }
      ]
      auto_scaling = {
        min_capacity = var.load_service_min_capacity
        max_capacity = var.load_service_max_capacity
        target_cpu   = var.load_service_target_cpu
        target_memory = var.load_service_target_memory
      }
    }
    "etl-validation-service" = {
      name            = "${var.project_name}-${var.environment}-etl-validation-service"
      task_definition = "etl-validation-task"
      desired_count   = var.validation_service_desired_count
      launch_type     = var.ecs_launch_type
      capacity_provider_strategy = var.ecs_launch_type == "FARGATE" ? null : [
        {
          capacity_provider = "FARGATE"
          weight           = 1
          base             = 0
        }
      ]
      auto_scaling = {
        min_capacity = var.validation_service_min_capacity
        max_capacity = var.validation_service_max_capacity
        target_cpu   = var.validation_service_target_cpu
        target_memory = var.validation_service_target_memory
      }
    }
  }
  
  # Task definitions
  task_definitions = {
    "etl-extract-task" = {
      family                   = "${var.project_name}-${var.environment}-etl-extract-task"
      network_mode            = "awsvpc"
      requires_compatibilities = [var.ecs_launch_type]
      cpu                     = var.extract_task_cpu
      memory                  = var.extract_task_memory
      execution_role_arn      = module.iam.ecs_execution_role_arn
      task_role_arn          = module.iam.ecs_task_role_arn
      container_definitions = [
        {
          name  = "etl-extract-container"
          image = "${module.ecr.repository_uris["etl-extract"]}:latest"
          cpu   = var.extract_task_cpu
          memory = var.extract_task_memory
          essential = true
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}-etl-extract"
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
          environment = [
            {
              name  = "AWS_DEFAULT_REGION"
              value = var.aws_region
            },
            {
              name  = "S3_BUCKET"
              value = module.s3.bucket_names["raw-data"]
            }
          ]
          secrets = [
            {
              name      = "DATABASE_PASSWORD"
              valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:etl/database-password"
            }
          ]
        }
      ]
    }
    "etl-transform-task" = {
      family                   = "${var.project_name}-${var.environment}-etl-transform-task"
      network_mode            = "awsvpc"
      requires_compatibilities = [var.ecs_launch_type]
      cpu                     = var.transform_task_cpu
      memory                  = var.transform_task_memory
      execution_role_arn      = module.iam.ecs_execution_role_arn
      task_role_arn          = module.iam.ecs_task_role_arn
      container_definitions = [
        {
          name  = "etl-transform-container"
          image = "${module.ecr.repository_uris["etl-transform"]}:latest"
          cpu   = var.transform_task_cpu
          memory = var.transform_task_memory
          essential = true
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}-etl-transform"
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
          environment = [
            {
              name  = "AWS_DEFAULT_REGION"
              value = var.aws_region
            },
            {
              name  = "S3_RAW_BUCKET"
              value = module.s3.bucket_names["raw-data"]
            },
            {
              name  = "S3_PROCESSED_BUCKET"
              value = module.s3.bucket_names["processed-data"]
            }
          ]
        }
      ]
    }
    "etl-load-task" = {
      family                   = "${var.project_name}-${var.environment}-etl-load-task"
      network_mode            = "awsvpc"
      requires_compatibilities = [var.ecs_launch_type]
      cpu                     = var.load_task_cpu
      memory                  = var.load_task_memory
      execution_role_arn      = module.iam.ecs_execution_role_arn
      task_role_arn          = module.iam.ecs_task_role_arn
      container_definitions = [
        {
          name  = "etl-load-container"
          image = "${module.ecr.repository_uris["etl-load"]}:latest"
          cpu   = var.load_task_cpu
          memory = var.load_task_memory
          essential = true
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}-etl-load"
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
          environment = [
            {
              name  = "AWS_DEFAULT_REGION"
              value = var.aws_region
            },
            {
              name  = "S3_PROCESSED_BUCKET"
              value = module.s3.bucket_names["processed-data"]
            },
            {
              name  = "REDSHIFT_ENDPOINT"
              value = var.enable_redshift ? module.redshift[0].cluster_endpoint : ""
            }
          ]
          secrets = [
            {
              name      = "REDSHIFT_PASSWORD"
              valueFrom = var.enable_redshift ? "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:etl/redshift-password" : ""
            }
          ]
        }
      ]
    }
    "etl-validation-task" = {
      family                   = "${var.project_name}-${var.environment}-etl-validation-task"
      network_mode            = "awsvpc"
      requires_compatibilities = [var.ecs_launch_type]
      cpu                     = var.validation_task_cpu
      memory                  = var.validation_task_memory
      execution_role_arn      = module.iam.ecs_execution_role_arn
      task_role_arn          = module.iam.ecs_task_role_arn
      container_definitions = [
        {
          name  = "etl-validation-container"
          image = "${module.ecr.repository_uris["etl-validation"]}:latest"
          cpu   = var.validation_task_cpu
          memory = var.validation_task_memory
          essential = true
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}-etl-validation"
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
          environment = [
            {
              name  = "AWS_DEFAULT_REGION"
              value = var.aws_region
            },
            {
              name  = "S3_PROCESSED_BUCKET"
              value = module.s3.bucket_names["processed-data"]
            }
          ]
        }
      ]
    }
  }
  
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
  cluster_identifier = "${var.project_name}-${var.environment}-container-warehouse"
  node_type          = var.redshift_node_type
  number_of_nodes    = var.redshift_number_of_nodes
  
  # Database configuration
  database_name = var.redshift_database_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password
  
  tags = local.common_tags
}

# Step Functions Module for Orchestration
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
          Resource = "arn:aws:states:::ecs:runTask.sync"
          Parameters = {
            TaskDefinition = module.ecs.task_definition_arns["etl-extract-task"]
            Cluster = module.ecs.cluster_arn
            LaunchType = var.ecs_launch_type
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                SecurityGroups = [module.vpc.security_group_id]
                Subnets = module.vpc.private_subnet_ids
                AssignPublicIp = "DISABLED"
              }
            }
          }
          Next = "TransformData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
        }
        TransformData = {
          Type = "Task"
          Resource = "arn:aws:states:::ecs:runTask.sync"
          Parameters = {
            TaskDefinition = module.ecs.task_definition_arns["etl-transform-task"]
            Cluster = module.ecs.cluster_arn
            LaunchType = var.ecs_launch_type
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                SecurityGroups = [module.vpc.security_group_id]
                Subnets = module.vpc.private_subnet_ids
                AssignPublicIp = "DISABLED"
              }
            }
          }
          Next = "ValidateData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
        }
        ValidateData = {
          Type = "Task"
          Resource = "arn:aws:states:::ecs:runTask.sync"
          Parameters = {
            TaskDefinition = module.ecs.task_definition_arns["etl-validation-task"]
            Cluster = module.ecs.cluster_arn
            LaunchType = var.ecs_launch_type
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                SecurityGroups = [module.vpc.security_group_id]
                Subnets = module.vpc.private_subnet_ids
                AssignPublicIp = "DISABLED"
              }
            }
          }
          Next = "LoadData"
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
        }
        LoadData = {
          Type = "Task"
          Resource = "arn:aws:states:::ecs:runTask.sync"
          Parameters = {
            TaskDefinition = module.ecs.task_definition_arns["etl-load-task"]
            Cluster = module.ecs.cluster_arn
            LaunchType = var.ecs_launch_type
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                SecurityGroups = [module.vpc.security_group_id]
                Subnets = module.vpc.private_subnet_ids
                AssignPublicIp = "DISABLED"
              }
            }
          }
          End = true
          Retry = [
            {
              ErrorEquals = ["States.ALL"]
              IntervalSeconds = 2
              MaxAttempts = 3
              BackoffRate = 2.0
            }
          ]
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
  }
  
  tags = local.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  project_name = var.project_name
  environment  = var.environment
  
  # ECS cluster ID for monitoring
  ecs_cluster_id = module.ecs.cluster_id
  
  # ECS service names for monitoring
  ecs_service_names = [
    module.ecs.service_names["etl-extract-service"],
    module.ecs.service_names["etl-transform-service"],
    module.ecs.service_names["etl-load-service"],
    module.ecs.service_names["etl-validation-service"]
  ]
  
  # S3 bucket names for monitoring
  s3_bucket_names = [
    module.s3.bucket_names["raw-data"],
    module.s3.bucket_names["processed-data"],
    module.s3.bucket_names["aggregated-data"]
  ]
  
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
  
  # ECR repository ARNs
  ecr_repository_arns = [
    module.ecr.repository_arns["etl-extract"],
    module.ecr.repository_arns["etl-transform"],
    module.ecr.repository_arns["etl-load"],
    module.ecr.repository_arns["etl-validation"]
  ]
  
  # ECS cluster ARN
  ecs_cluster_arn = module.ecs.cluster_arn
  
  # Redshift cluster ARN (if enabled)
  redshift_cluster_arn = var.enable_redshift ? module.redshift[0].cluster_arn : null
  
  # Step Functions state machine ARN
  step_functions_state_machine_arn = module.step_functions.state_machine_arn
  
  tags = local.common_tags
}
