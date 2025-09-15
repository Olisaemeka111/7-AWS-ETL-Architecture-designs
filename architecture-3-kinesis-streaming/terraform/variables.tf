# Architecture 3: Kinesis Streaming ETL - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "kinesis-streaming-etl"
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

# Kinesis Configuration
variable "kinesis_shard_count" {
  description = "Number of shards for main Kinesis stream"
  type        = number
  default     = 2
  validation {
    condition     = var.kinesis_shard_count >= 1 && var.kinesis_shard_count <= 500
    error_message = "Kinesis shard count must be between 1 and 500."
  }
}

variable "analytics_shard_count" {
  description = "Number of shards for analytics Kinesis stream"
  type        = number
  default     = 1
  validation {
    condition     = var.analytics_shard_count >= 1 && var.analytics_shard_count <= 500
    error_message = "Analytics shard count must be between 1 and 500."
  }
}

variable "kinesis_retention_period" {
  description = "Data retention period for Kinesis streams in hours"
  type        = number
  default     = 24
  validation {
    condition     = var.kinesis_retention_period >= 24 && var.kinesis_retention_period <= 8760
    error_message = "Kinesis retention period must be between 24 and 8760 hours."
  }
}

variable "kinesis_encryption_type" {
  description = "Encryption type for Kinesis streams"
  type        = string
  default     = "KMS"
  validation {
    condition     = contains(["NONE", "KMS"], var.kinesis_encryption_type)
    error_message = "Kinesis encryption type must be either NONE or KMS."
  }
}

# Kinesis Analytics Configuration
variable "kinesis_analytics_sql" {
  description = "SQL code for Kinesis Analytics application"
  type        = string
  default     = <<-EOF
    CREATE STREAM "input_stream" (
        user_id VARCHAR(64),
        event_type VARCHAR(32),
        timestamp TIMESTAMP,
        value DOUBLE
    );
    
    CREATE STREAM "output_stream" (
        user_id VARCHAR(64),
        event_type VARCHAR(32),
        timestamp TIMESTAMP,
        value DOUBLE,
        processed_at TIMESTAMP
    );
    
    CREATE PUMP "stream_pump" AS
    INSERT INTO "output_stream"
    SELECT 
        user_id,
        event_type,
        timestamp,
        value,
        ROWTIME as processed_at
    FROM "input_stream";
  EOF
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
  default     = "streaming_warehouse"
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

variable "redshift_table_name" {
  description = "Redshift table name for streaming data"
  type        = string
  default     = "streaming_events"
}

# OpenSearch Configuration
variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
  validation {
    condition = contains([
      "t3.small.search", "t3.medium.search", "t3.large.search",
      "m5.large.search", "m5.xlarge.search", "m5.2xlarge.search",
      "r5.large.search", "r5.xlarge.search", "r5.2xlarge.search"
    ], var.opensearch_instance_type)
    error_message = "Invalid OpenSearch instance type."
  }
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
  validation {
    condition     = var.opensearch_instance_count >= 1 && var.opensearch_instance_count <= 20
    error_message = "OpenSearch instance count must be between 1 and 20."
  }
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Default timeout for Lambda functions in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Default memory size for Lambda functions in MB"
  type        = number
  default     = 512
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

# Data Processing Configuration
variable "enrichment_table_name" {
  description = "Name of the enrichment table for data enrichment"
  type        = string
  default     = "user_enrichment"
}

variable "batch_size" {
  description = "Batch size for processing records"
  type        = number
  default     = 100
  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10000
    error_message = "Batch size must be between 1 and 10000."
  }
}

variable "processing_interval" {
  description = "Processing interval in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.processing_interval >= 1 && var.processing_interval <= 3600
    error_message = "Processing interval must be between 1 and 3600 seconds."
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

# Alerting Configuration
variable "alert_emails" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "notification_emails" {
  description = "List of email addresses for notifications"
  type        = list(string)
  default     = []
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
  description = "Enable auto-scaling for Kinesis streams"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
