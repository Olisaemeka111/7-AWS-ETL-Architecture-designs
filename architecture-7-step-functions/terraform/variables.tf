# Architecture 7: Step Functions ETL - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "step-functions-etl"
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

# Lambda Configuration
variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 1024
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
  validation {
    condition     = contains(["python3.8", "python3.9", "python3.10", "python3.11"], var.lambda_runtime)
    error_message = "Lambda runtime must be one of: python3.8, python3.9, python3.10, python3.11."
  }
}

# Glue Configuration
variable "glue_max_capacity" {
  description = "Maximum capacity for Glue jobs"
  type        = number
  default     = 2
  validation {
    condition     = var.glue_max_capacity >= 2 && var.glue_max_capacity <= 100
    error_message = "Glue max capacity must be between 2 and 100."
  }
}

variable "glue_timeout" {
  description = "Timeout for Glue jobs in minutes"
  type        = number
  default     = 60
  validation {
    condition     = var.glue_timeout >= 1 && var.glue_timeout <= 2880
    error_message = "Glue timeout must be between 1 and 2880 minutes."
  }
}

variable "glue_version" {
  description = "Glue version"
  type        = string
  default     = "4.0"
  validation {
    condition     = contains(["1.0", "2.0", "3.0", "4.0"], var.glue_version)
    error_message = "Glue version must be one of: 1.0, 2.0, 3.0, 4.0."
  }
}

# EMR Configuration
variable "enable_emr" {
  description = "Enable EMR cluster"
  type        = bool
  default     = false
}

variable "emr_release_label" {
  description = "EMR release label"
  type        = string
  default     = "emr-6.15.0"
  validation {
    condition     = can(regex("^emr-[0-9]+\\.[0-9]+\\.[0-9]+$", var.emr_release_label))
    error_message = "EMR release label must be in format emr-x.y.z."
  }
}

variable "emr_applications" {
  description = "EMR applications"
  type        = list(string)
  default     = ["Spark", "Hadoop", "Hive"]
}

variable "emr_master_instance_type" {
  description = "EMR master instance type"
  type        = string
  default     = "m5.xlarge"
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge"
    ], var.emr_master_instance_type)
    error_message = "Invalid EMR master instance type."
  }
}

variable "emr_core_instance_type" {
  description = "EMR core instance type"
  type        = string
  default     = "m5.xlarge"
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge"
    ], var.emr_core_instance_type)
    error_message = "Invalid EMR core instance type."
  }
}

variable "emr_core_instance_count" {
  description = "Number of EMR core instances"
  type        = number
  default     = 2
  validation {
    condition     = var.emr_core_instance_count >= 1 && var.emr_core_instance_count <= 100
    error_message = "EMR core instance count must be between 1 and 100."
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
  default     = "step_functions_warehouse"
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

# Step Functions Configuration
variable "step_functions_type" {
  description = "Step Functions type (STANDARD or EXPRESS)"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.step_functions_type)
    error_message = "Step Functions type must be either STANDARD or EXPRESS."
  }
}

variable "step_functions_logging_level" {
  description = "Step Functions logging level"
  type        = string
  default     = "ERROR"
  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.step_functions_logging_level)
    error_message = "Step Functions logging level must be one of: ALL, ERROR, FATAL, OFF."
  }
}

variable "step_functions_tracing_enabled" {
  description = "Enable X-Ray tracing for Step Functions"
  type        = bool
  default     = true
}

# ETL Configuration
variable "etl_schedule_expression" {
  description = "Schedule expression for ETL jobs"
  type        = string
  default     = "rate(1 hour)"
}

variable "etl_batch_size" {
  description = "Batch size for ETL processing"
  type        = number
  default     = 1000
  validation {
    condition     = var.etl_batch_size >= 1 && var.etl_batch_size <= 10000
    error_message = "ETL batch size must be between 1 and 10000."
  }
}

variable "etl_max_retries" {
  description = "Maximum number of retries for ETL operations"
  type        = number
  default     = 3
  validation {
    condition     = var.etl_max_retries >= 0 && var.etl_max_retries <= 10
    error_message = "ETL max retries must be between 0 and 10."
  }
}

variable "etl_retry_delay" {
  description = "Delay between retries in seconds"
  type        = number
  default     = 5
  validation {
    condition     = var.etl_retry_delay >= 1 && var.etl_retry_delay <= 300
    error_message = "ETL retry delay must be between 1 and 300 seconds."
  }
}

# Notification Configuration
variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "alerts@example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address."
  }
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = "notifications@example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
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

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
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

# Performance Configuration
variable "enable_auto_scaling" {
  description = "Enable auto-scaling for services"
  type        = bool
  default     = true
}

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

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "reserved_capacity_enabled" {
  description = "Enable reserved capacity for cost savings"
  type        = bool
  default     = false
}

# Data Quality Configuration
variable "enable_data_quality_checks" {
  description = "Enable data quality validation"
  type        = bool
  default     = true
}

variable "data_quality_threshold" {
  description = "Data quality threshold percentage"
  type        = number
  default     = 95
  validation {
    condition     = var.data_quality_threshold >= 0 && var.data_quality_threshold <= 100
    error_message = "Data quality threshold must be between 0 and 100."
  }
}

# Disaster Recovery Configuration
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
