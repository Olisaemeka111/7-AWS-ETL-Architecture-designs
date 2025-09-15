# Architecture 2: AWS Glue ETL Pipeline - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "etl-glue-pipeline"
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

# Glue Job Configuration
variable "extract_job_dpu" {
  description = "Number of DPUs for extract job"
  type        = number
  default     = 2
  validation {
    condition     = var.extract_job_dpu >= 2 && var.extract_job_dpu <= 100
    error_message = "Extract job DPU must be between 2 and 100."
  }
}

variable "transform_job_dpu" {
  description = "Number of DPUs for transform job"
  type        = number
  default     = 4
  validation {
    condition     = var.transform_job_dpu >= 2 && var.transform_job_dpu <= 100
    error_message = "Transform job DPU must be between 2 and 100."
  }
}

variable "load_job_dpu" {
  description = "Number of DPUs for load job"
  type        = number
  default     = 3
  validation {
    condition     = var.load_job_dpu >= 2 && var.load_job_dpu <= 100
    error_message = "Load job DPU must be between 2 and 100."
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
  default     = "etl_warehouse"
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

# Data Source Configuration
variable "source_databases" {
  description = "List of source databases to connect to"
  type = list(object({
    name        = string
    type        = string
    host        = string
    port        = number
    database    = string
    username    = string
    password    = string
    description = string
  }))
  default = []
}

variable "source_s3_paths" {
  description = "List of S3 paths to crawl"
  type = list(object({
    name        = string
    path        = string
    format      = string
    description = string
  }))
  default = [
    {
      name        = "sample-data"
      path        = "s3://aws-glue-datasets/examples/us-legislators/all/"
      format      = "json"
      description = "Sample legislators data"
    }
  ]
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

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for Glue jobs"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
