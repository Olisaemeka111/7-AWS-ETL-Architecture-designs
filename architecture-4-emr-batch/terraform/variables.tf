# Architecture 4: EMR Batch ETL - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "emr-batch-etl"
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

# EMR Cluster Configuration
variable "master_instance_type" {
  description = "EC2 instance type for EMR master node"
  type        = string
  default     = "m5.xlarge"
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge", "r5.12xlarge", "r5.16xlarge", "r5.24xlarge"
    ], var.master_instance_type)
    error_message = "Invalid master instance type."
  }
}

variable "core_instance_type" {
  description = "EC2 instance type for EMR core nodes"
  type        = string
  default     = "m5.large"
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge", "r5.12xlarge", "r5.16xlarge", "r5.24xlarge"
    ], var.core_instance_type)
    error_message = "Invalid core instance type."
  }
}

variable "core_instance_count" {
  description = "Number of core instances in the EMR cluster"
  type        = number
  default     = 2
  validation {
    condition     = var.core_instance_count >= 1 && var.core_instance_count <= 100
    error_message = "Core instance count must be between 1 and 100."
  }
}

variable "task_instance_type" {
  description = "EC2 instance type for EMR task nodes"
  type        = string
  default     = "m5.large"
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge", "r5.12xlarge", "r5.16xlarge", "r5.24xlarge"
    ], var.task_instance_type)
    error_message = "Invalid task instance type."
  }
}

variable "task_instance_count" {
  description = "Number of task instances in the EMR cluster"
  type        = number
  default     = 0
  validation {
    condition     = var.task_instance_count >= 0 && var.task_instance_count <= 100
    error_message = "Task instance count must be between 0 and 100."
  }
}

# Auto-scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable auto-scaling for EMR cluster"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of task instances for auto-scaling"
  type        = number
  default     = 0
  validation {
    condition     = var.min_capacity >= 0 && var.min_capacity <= 100
    error_message = "Min capacity must be between 0 and 100."
  }
}

variable "max_capacity" {
  description = "Maximum number of task instances for auto-scaling"
  type        = number
  default     = 20
  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity <= 100
    error_message = "Max capacity must be between 1 and 100."
  }
}

# Spot Instance Configuration
variable "enable_spot_instances" {
  description = "Enable spot instances for task nodes"
  type        = bool
  default     = true
}

variable "spot_bid_price" {
  description = "Bid price for spot instances"
  type        = string
  default     = "0.10"
}

# EMR Applications
variable "emr_applications" {
  description = "List of applications to install on EMR cluster"
  type        = list(string)
  default     = ["Spark", "Hadoop", "Hive", "Pig", "Hue", "Zeppelin"]
}

# Bootstrap Actions
variable "bootstrap_actions" {
  description = "List of bootstrap actions for EMR cluster"
  type = list(object({
    name = string
    path = string
    args = list(string)
  }))
  default = [
    {
      name = "Install Python packages"
      path = "s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/install_python_packages.sh"
      args = ["pandas", "numpy", "scikit-learn"]
    }
  ]
}

# EMR Steps
variable "emr_steps" {
  description = "List of EMR steps to execute"
  type = list(object({
    name              = string
    action_on_failure = string
    hadoop_jar_step = object({
      jar  = string
      args = list(string)
    })
  }))
  default = []
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
  default     = "batch_warehouse"
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

# Airflow Configuration
variable "enable_airflow" {
  description = "Enable Apache Airflow for orchestration"
  type        = bool
  default     = false
}

variable "airflow_version" {
  description = "Apache Airflow version"
  type        = string
  default     = "2.0.2"
}

variable "airflow_instance_type" {
  description = "EC2 instance type for Airflow workers"
  type        = string
  default     = "m5.large"
}

variable "airflow_min_workers" {
  description = "Minimum number of Airflow workers"
  type        = number
  default     = 1
  validation {
    condition     = var.airflow_min_workers >= 1 && var.airflow_min_workers <= 10
    error_message = "Airflow min workers must be between 1 and 10."
  }
}

variable "airflow_max_workers" {
  description = "Maximum number of Airflow workers"
  type        = number
  default     = 5
  validation {
    condition     = var.airflow_max_workers >= 1 && var.airflow_max_workers <= 20
    error_message = "Airflow max workers must be between 1 and 20."
  }
}

# Data Processing Configuration
variable "batch_size" {
  description = "Batch size for data processing"
  type        = number
  default     = 1000
  validation {
    condition     = var.batch_size >= 100 && var.batch_size <= 100000
    error_message = "Batch size must be between 100 and 100000."
  }
}

variable "processing_interval" {
  description = "Processing interval in hours"
  type        = number
  default     = 24
  validation {
    condition     = var.processing_interval >= 1 && var.processing_interval <= 168
    error_message = "Processing interval must be between 1 and 168 hours."
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
variable "enable_cluster_termination_protection" {
  description = "Enable termination protection for EMR cluster"
  type        = bool
  default     = false
}

variable "cluster_termination_timeout" {
  description = "Timeout in minutes for cluster termination"
  type        = number
  default     = 60
  validation {
    condition     = var.cluster_termination_timeout >= 0 && var.cluster_termination_timeout <= 1440
    error_message = "Cluster termination timeout must be between 0 and 1440 minutes."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
