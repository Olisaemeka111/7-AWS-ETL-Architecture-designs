# Architecture 6: Containerized ETL with ECS - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "containerized-ecs-etl"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ECS Configuration
variable "ecs_launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "ECS launch type must be either FARGATE or EC2."
  }
}

variable "ecs_capacity_providers" {
  description = "List of ECS capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "ecs_default_capacity_provider_strategy" {
  description = "Default capacity provider strategy for ECS cluster"
  type = list(object({
    capacity_provider = string
    weight           = number
    base             = number
  }))
  default = [
    {
      capacity_provider = "FARGATE"
      weight           = 1
      base             = 0
    }
  ]
}

variable "ecs_container_insights" {
  description = "Enable container insights for ECS cluster"
  type        = bool
  default     = true
}

# Extract Service Configuration
variable "extract_service_desired_count" {
  description = "Desired count for extract service"
  type        = number
  default     = 1
  validation {
    condition     = var.extract_service_desired_count >= 0 && var.extract_service_desired_count <= 100
    error_message = "Extract service desired count must be between 0 and 100."
  }
}

variable "extract_service_min_capacity" {
  description = "Minimum capacity for extract service auto-scaling"
  type        = number
  default     = 1
  validation {
    condition     = var.extract_service_min_capacity >= 0 && var.extract_service_min_capacity <= 100
    error_message = "Extract service min capacity must be between 0 and 100."
  }
}

variable "extract_service_max_capacity" {
  description = "Maximum capacity for extract service auto-scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.extract_service_max_capacity >= 1 && var.extract_service_max_capacity <= 100
    error_message = "Extract service max capacity must be between 1 and 100."
  }
}

variable "extract_service_target_cpu" {
  description = "Target CPU utilization for extract service auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.extract_service_target_cpu >= 1 && var.extract_service_target_cpu <= 100
    error_message = "Extract service target CPU must be between 1 and 100."
  }
}

variable "extract_service_target_memory" {
  description = "Target memory utilization for extract service auto-scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.extract_service_target_memory >= 1 && var.extract_service_target_memory <= 100
    error_message = "Extract service target memory must be between 1 and 100."
  }
}

variable "extract_task_cpu" {
  description = "CPU allocation for extract task"
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.extract_task_cpu)
    error_message = "Extract task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "extract_task_memory" {
  description = "Memory allocation for extract task"
  type        = number
  default     = 2048
  validation {
    condition     = var.extract_task_memory >= 512 && var.extract_task_memory <= 16384
    error_message = "Extract task memory must be between 512 and 16384 MB."
  }
}

# Transform Service Configuration
variable "transform_service_desired_count" {
  description = "Desired count for transform service"
  type        = number
  default     = 1
  validation {
    condition     = var.transform_service_desired_count >= 0 && var.transform_service_desired_count <= 100
    error_message = "Transform service desired count must be between 0 and 100."
  }
}

variable "transform_service_min_capacity" {
  description = "Minimum capacity for transform service auto-scaling"
  type        = number
  default     = 1
  validation {
    condition     = var.transform_service_min_capacity >= 0 && var.transform_service_min_capacity <= 100
    error_message = "Transform service min capacity must be between 0 and 100."
  }
}

variable "transform_service_max_capacity" {
  description = "Maximum capacity for transform service auto-scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.transform_service_max_capacity >= 1 && var.transform_service_max_capacity <= 100
    error_message = "Transform service max capacity must be between 1 and 100."
  }
}

variable "transform_service_target_cpu" {
  description = "Target CPU utilization for transform service auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.transform_service_target_cpu >= 1 && var.transform_service_target_cpu <= 100
    error_message = "Transform service target CPU must be between 1 and 100."
  }
}

variable "transform_service_target_memory" {
  description = "Target memory utilization for transform service auto-scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.transform_service_target_memory >= 1 && var.transform_service_target_memory <= 100
    error_message = "Transform service target memory must be between 1 and 100."
  }
}

variable "transform_task_cpu" {
  description = "CPU allocation for transform task"
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.transform_task_cpu)
    error_message = "Transform task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "transform_task_memory" {
  description = "Memory allocation for transform task"
  type        = number
  default     = 2048
  validation {
    condition     = var.transform_task_memory >= 512 && var.transform_task_memory <= 16384
    error_message = "Transform task memory must be between 512 and 16384 MB."
  }
}

# Load Service Configuration
variable "load_service_desired_count" {
  description = "Desired count for load service"
  type        = number
  default     = 1
  validation {
    condition     = var.load_service_desired_count >= 0 && var.load_service_desired_count <= 100
    error_message = "Load service desired count must be between 0 and 100."
  }
}

variable "load_service_min_capacity" {
  description = "Minimum capacity for load service auto-scaling"
  type        = number
  default     = 1
  validation {
    condition     = var.load_service_min_capacity >= 0 && var.load_service_min_capacity <= 100
    error_message = "Load service min capacity must be between 0 and 100."
  }
}

variable "load_service_max_capacity" {
  description = "Maximum capacity for load service auto-scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.load_service_max_capacity >= 1 && var.load_service_max_capacity <= 100
    error_message = "Load service max capacity must be between 1 and 100."
  }
}

variable "load_service_target_cpu" {
  description = "Target CPU utilization for load service auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.load_service_target_cpu >= 1 && var.load_service_target_cpu <= 100
    error_message = "Load service target CPU must be between 1 and 100."
  }
}

variable "load_service_target_memory" {
  description = "Target memory utilization for load service auto-scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.load_service_target_memory >= 1 && var.load_service_target_memory <= 100
    error_message = "Load service target memory must be between 1 and 100."
  }
}

variable "load_task_cpu" {
  description = "CPU allocation for load task"
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.load_task_cpu)
    error_message = "Load task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "load_task_memory" {
  description = "Memory allocation for load task"
  type        = number
  default     = 2048
  validation {
    condition     = var.load_task_memory >= 512 && var.load_task_memory <= 16384
    error_message = "Load task memory must be between 512 and 16384 MB."
  }
}

# Validation Service Configuration
variable "validation_service_desired_count" {
  description = "Desired count for validation service"
  type        = number
  default     = 1
  validation {
    condition     = var.validation_service_desired_count >= 0 && var.validation_service_desired_count <= 100
    error_message = "Validation service desired count must be between 0 and 100."
  }
}

variable "validation_service_min_capacity" {
  description = "Minimum capacity for validation service auto-scaling"
  type        = number
  default     = 1
  validation {
    condition     = var.validation_service_min_capacity >= 0 && var.validation_service_min_capacity <= 100
    error_message = "Validation service min capacity must be between 0 and 100."
  }
}

variable "validation_service_max_capacity" {
  description = "Maximum capacity for validation service auto-scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.validation_service_max_capacity >= 1 && var.validation_service_max_capacity <= 100
    error_message = "Validation service max capacity must be between 1 and 100."
  }
}

variable "validation_service_target_cpu" {
  description = "Target CPU utilization for validation service auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.validation_service_target_cpu >= 1 && var.validation_service_target_cpu <= 100
    error_message = "Validation service target CPU must be between 1 and 100."
  }
}

variable "validation_service_target_memory" {
  description = "Target memory utilization for validation service auto-scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.validation_service_target_memory >= 1 && var.validation_service_target_memory <= 100
    error_message = "Validation service target memory must be between 1 and 100."
  }
}

variable "validation_task_cpu" {
  description = "CPU allocation for validation task"
  type        = number
  default     = 512
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.validation_task_cpu)
    error_message = "Validation task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "validation_task_memory" {
  description = "Memory allocation for validation task"
  type        = number
  default     = 1024
  validation {
    condition     = var.validation_task_memory >= 512 && var.validation_task_memory <= 16384
    error_message = "Validation task memory must be between 512 and 16384 MB."
  }
}

# Redshift Configuration
variable "enable_redshift" {
  description = "Enable Redshift data warehouse"
  type        = bool
  default     = true
}

variable "redshift_node_type" {
  description = "Redshift node type"
  type        = string
  default     = "dc2.large"
  validation {
    condition = contains([
      "dc2.large", "dc2.xlarge", "dc2.2xlarge", "dc2.4xlarge", "dc2.8xlarge",
      "ra3.xlplus", "ra3.2xlplus", "ra3.4xlplus", "ra3.8xlplus", "ra3.16xlplus"
    ], var.redshift_node_type)
    error_message = "Invalid Redshift node type."
  }
}

variable "redshift_number_of_nodes" {
  description = "Number of Redshift nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.redshift_number_of_nodes >= 1 && var.redshift_number_of_nodes <= 100
    error_message = "Number of Redshift nodes must be between 1 and 100."
  }
}

variable "redshift_database_name" {
  description = "Redshift database name"
  type        = string
  default     = "container_warehouse"
}

variable "redshift_master_username" {
  description = "Redshift master username"
  type        = string
  default     = "admin"
}

variable "redshift_master_password" {
  description = "Redshift master password"
  type        = string
  sensitive   = true
  default     = "TempPassword123!"
  validation {
    condition     = length(var.redshift_master_password) >= 8
    error_message = "Redshift master password must be at least 8 characters long."
  }
}

# ETL Configuration
variable "etl_schedule_expression" {
  description = "Schedule expression for ETL jobs"
  type        = string
  default     = "rate(1 hour)"
}

# Monitoring Configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 3653
    ], var.log_retention_days)
    error_message = "Invalid log retention period."
  }
}

# Security Configuration
variable "enable_encryption" {
  description = "Enable encryption for all resources"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional)"
  type        = string
  default     = null
}

# Container Configuration
variable "container_image_tag" {
  description = "Tag for container images"
  type        = string
  default     = "latest"
}

variable "container_registry_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

variable "container_lifecycle_policy" {
  description = "ECR lifecycle policy for container images"
  type = object({
    max_image_count = number
    max_image_age_days = number
  })
  default = {
    max_image_count = 10
    max_image_age_days = 30
  }
}

# Auto-scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable auto-scaling for ECS services"
  type        = bool
  default     = true
}

variable "auto_scaling_scale_out_cooldown" {
  description = "Scale out cooldown period in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.auto_scaling_scale_out_cooldown >= 0 && var.auto_scaling_scale_out_cooldown <= 3600
    error_message = "Scale out cooldown must be between 0 and 3600 seconds."
  }
}

variable "auto_scaling_scale_in_cooldown" {
  description = "Scale in cooldown period in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.auto_scaling_scale_in_cooldown >= 0 && var.auto_scaling_scale_in_cooldown <= 3600
    error_message = "Scale in cooldown must be between 0 and 3600 seconds."
  }
}

# Performance Configuration
variable "enable_performance_insights" {
  description = "Enable performance insights for ECS tasks"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for ECS tasks"
  type        = bool
  default     = true
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_instance_percentage" {
  description = "Percentage of spot instances to use"
  type        = number
  default     = 0
  validation {
    condition     = var.spot_instance_percentage >= 0 && var.spot_instance_percentage <= 100
    error_message = "Spot instance percentage must be between 0 and 100."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
