# Architecture 5: RDS Database ETL - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "rds-database-etl"
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

# Source RDS Configuration
variable "source_db_name" {
  description = "Name of the source database"
  type        = string
  default     = "sourcedb"
}

variable "source_db_username" {
  description = "Username for the source database"
  type        = string
  default     = "admin"
}

variable "source_db_password" {
  description = "Password for the source database"
  type        = string
  sensitive   = true
  default     = "TempPassword123!"
  validation {
    condition     = length(var.source_db_password) >= 8
    error_message = "Source database password must be at least 8 characters long."
  }
}

variable "source_instance_class" {
  description = "Instance class for the source RDS instance"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large", "db.t3.xlarge", "db.t3.2xlarge",
      "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge", "db.r5.4xlarge", "db.r5.8xlarge", "db.r5.12xlarge", "db.r5.16xlarge", "db.r5.24xlarge",
      "db.m5.large", "db.m5.xlarge", "db.m5.2xlarge", "db.m5.4xlarge", "db.m5.8xlarge", "db.m5.12xlarge", "db.m5.16xlarge", "db.m5.24xlarge"
    ], var.source_instance_class)
    error_message = "Invalid source instance class."
  }
}

variable "source_allocated_storage" {
  description = "Allocated storage for the source RDS instance (GB)"
  type        = number
  default     = 20
  validation {
    condition     = var.source_allocated_storage >= 20 && var.source_allocated_storage <= 65536
    error_message = "Source allocated storage must be between 20 and 65536 GB."
  }
}

variable "source_max_allocated_storage" {
  description = "Maximum allocated storage for the source RDS instance (GB)"
  type        = number
  default     = 100
  validation {
    condition     = var.source_max_allocated_storage >= var.source_allocated_storage
    error_message = "Source max allocated storage must be greater than or equal to allocated storage."
  }
}

variable "source_storage_type" {
  description = "Storage type for the source RDS instance"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2"], var.source_storage_type)
    error_message = "Source storage type must be one of: standard, gp2, gp3, io1, io2."
  }
}

variable "source_storage_encrypted" {
  description = "Enable encryption for the source RDS instance"
  type        = bool
  default     = true
}

variable "source_engine" {
  description = "Database engine for the source RDS instance"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql", "mariadb", "oracle-ee", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"], var.source_engine)
    error_message = "Invalid source engine."
  }
}

variable "source_engine_version" {
  description = "Engine version for the source RDS instance"
  type        = string
  default     = "13.7"
}

variable "source_backup_retention_period" {
  description = "Backup retention period for the source RDS instance (days)"
  type        = number
  default     = 7
  validation {
    condition     = var.source_backup_retention_period >= 0 && var.source_backup_retention_period <= 35
    error_message = "Source backup retention period must be between 0 and 35 days."
  }
}

variable "source_backup_window" {
  description = "Backup window for the source RDS instance"
  type        = string
  default     = "03:00-04:00"
}

variable "source_maintenance_window" {
  description = "Maintenance window for the source RDS instance"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "source_monitoring_interval" {
  description = "Monitoring interval for the source RDS instance"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.source_monitoring_interval)
    error_message = "Source monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "source_monitoring_role_arn" {
  description = "Monitoring role ARN for the source RDS instance"
  type        = string
  default     = null
}

variable "source_deletion_protection" {
  description = "Enable deletion protection for the source RDS instance"
  type        = bool
  default     = true
}

variable "source_skip_final_snapshot" {
  description = "Skip final snapshot for the source RDS instance"
  type        = bool
  default     = false
}

variable "source_port" {
  description = "Port for the source database"
  type        = number
  default     = 5432
}

# Target RDS Configuration
variable "target_db_name" {
  description = "Name of the target database"
  type        = string
  default     = "targetdb"
}

variable "target_db_username" {
  description = "Username for the target database"
  type        = string
  default     = "admin"
}

variable "target_db_password" {
  description = "Password for the target database"
  type        = string
  sensitive   = true
  default     = "TempPassword123!"
  validation {
    condition     = length(var.target_db_password) >= 8
    error_message = "Target database password must be at least 8 characters long."
  }
}

variable "target_instance_class" {
  description = "Instance class for the target RDS instance"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large", "db.t3.xlarge", "db.t3.2xlarge",
      "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge", "db.r5.4xlarge", "db.r5.8xlarge", "db.r5.12xlarge", "db.r5.16xlarge", "db.r5.24xlarge",
      "db.m5.large", "db.m5.xlarge", "db.m5.2xlarge", "db.m5.4xlarge", "db.m5.8xlarge", "db.m5.12xlarge", "db.m5.16xlarge", "db.m5.24xlarge"
    ], var.target_instance_class)
    error_message = "Invalid target instance class."
  }
}

variable "target_allocated_storage" {
  description = "Allocated storage for the target RDS instance (GB)"
  type        = number
  default     = 20
  validation {
    condition     = var.target_allocated_storage >= 20 && var.target_allocated_storage <= 65536
    error_message = "Target allocated storage must be between 20 and 65536 GB."
  }
}

variable "target_max_allocated_storage" {
  description = "Maximum allocated storage for the target RDS instance (GB)"
  type        = number
  default     = 100
  validation {
    condition     = var.target_max_allocated_storage >= var.target_allocated_storage
    error_message = "Target max allocated storage must be greater than or equal to allocated storage."
  }
}

variable "target_storage_type" {
  description = "Storage type for the target RDS instance"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2"], var.target_storage_type)
    error_message = "Target storage type must be one of: standard, gp2, gp3, io1, io2."
  }
}

variable "target_storage_encrypted" {
  description = "Enable encryption for the target RDS instance"
  type        = bool
  default     = true
}

variable "target_engine" {
  description = "Database engine for the target RDS instance"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql", "mariadb", "oracle-ee", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"], var.target_engine)
    error_message = "Invalid target engine."
  }
}

variable "target_engine_version" {
  description = "Engine version for the target RDS instance"
  type        = string
  default     = "13.7"
}

variable "target_backup_retention_period" {
  description = "Backup retention period for the target RDS instance (days)"
  type        = number
  default     = 7
  validation {
    condition     = var.target_backup_retention_period >= 0 && var.target_backup_retention_period <= 35
    error_message = "Target backup retention period must be between 0 and 35 days."
  }
}

variable "target_backup_window" {
  description = "Backup window for the target RDS instance"
  type        = string
  default     = "03:00-04:00"
}

variable "target_maintenance_window" {
  description = "Maintenance window for the target RDS instance"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "target_monitoring_interval" {
  description = "Monitoring interval for the target RDS instance"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.target_monitoring_interval)
    error_message = "Target monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "target_monitoring_role_arn" {
  description = "Monitoring role ARN for the target RDS instance"
  type        = string
  default     = null
}

variable "target_deletion_protection" {
  description = "Enable deletion protection for the target RDS instance"
  type        = bool
  default     = true
}

variable "target_skip_final_snapshot" {
  description = "Skip final snapshot for the target RDS instance"
  type        = bool
  default     = false
}

variable "target_port" {
  description = "Port for the target database"
  type        = number
  default     = 5432
}

# Aurora Configuration
variable "enable_aurora" {
  description = "Enable Aurora cluster"
  type        = bool
  default     = false
}

variable "aurora_database_name" {
  description = "Name of the Aurora database"
  type        = string
  default     = "auroradb"
}

variable "aurora_master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "admin"
}

variable "aurora_master_password" {
  description = "Master password for the Aurora cluster"
  type        = string
  sensitive   = true
  default     = "TempPassword123!"
  validation {
    condition     = length(var.aurora_master_password) >= 8
    error_message = "Aurora master password must be at least 8 characters long."
  }
}

variable "aurora_engine" {
  description = "Database engine for the Aurora cluster"
  type        = string
  default     = "aurora-postgresql"
  validation {
    condition     = contains(["aurora", "aurora-mysql", "aurora-postgresql"], var.aurora_engine)
    error_message = "Aurora engine must be one of: aurora, aurora-mysql, aurora-postgresql."
  }
}

variable "aurora_engine_version" {
  description = "Engine version for the Aurora cluster"
  type        = string
  default     = "13.7"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.r5.large"
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 2
  validation {
    condition     = var.aurora_instance_count >= 1 && var.aurora_instance_count <= 15
    error_message = "Aurora instance count must be between 1 and 15."
  }
}

variable "aurora_backup_retention_period" {
  description = "Backup retention period for the Aurora cluster (days)"
  type        = number
  default     = 7
  validation {
    condition     = var.aurora_backup_retention_period >= 1 && var.aurora_backup_retention_period <= 35
    error_message = "Aurora backup retention period must be between 1 and 35 days."
  }
}

variable "aurora_backup_window" {
  description = "Backup window for the Aurora cluster"
  type        = string
  default     = "03:00-04:00"
}

variable "aurora_maintenance_window" {
  description = "Maintenance window for the Aurora cluster"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection for the Aurora cluster"
  type        = bool
  default     = true
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot for the Aurora cluster"
  type        = bool
  default     = false
}

# DMS Configuration
variable "dms_instance_class" {
  description = "Instance class for the DMS replication instance"
  type        = string
  default     = "dms.t3.micro"
  validation {
    condition = contains([
      "dms.t3.micro", "dms.t3.small", "dms.t3.medium", "dms.t3.large", "dms.t3.xlarge", "dms.t3.2xlarge",
      "dms.c4.large", "dms.c4.xlarge", "dms.c4.2xlarge", "dms.c4.4xlarge", "dms.c4.8xlarge",
      "dms.c5.large", "dms.c5.xlarge", "dms.c5.2xlarge", "dms.c5.4xlarge", "dms.c5.9xlarge", "dms.c5.12xlarge", "dms.c5.18xlarge", "dms.c5.24xlarge",
      "dms.r4.large", "dms.r4.xlarge", "dms.r4.2xlarge", "dms.r4.4xlarge", "dms.r4.8xlarge", "dms.r4.16xlarge",
      "dms.r5.large", "dms.r5.xlarge", "dms.r5.2xlarge", "dms.r5.4xlarge", "dms.r5.8xlarge", "dms.r5.12xlarge", "dms.r5.16xlarge", "dms.r5.24xlarge"
    ], var.dms_instance_class)
    error_message = "Invalid DMS instance class."
  }
}

variable "dms_allocated_storage" {
  description = "Allocated storage for the DMS replication instance (GB)"
  type        = number
  default     = 50
  validation {
    condition     = var.dms_allocated_storage >= 5 && var.dms_allocated_storage <= 6144
    error_message = "DMS allocated storage must be between 5 and 6144 GB."
  }
}

variable "dms_replication_tasks" {
  description = "List of DMS replication tasks"
  type = list(object({
    task_id          = string
    migration_type   = string
    table_mappings   = string
    replication_task_settings = optional(string)
  }))
  default = [
    {
      task_id        = "full-load-and-cdc"
      migration_type = "full-load-and-cdc"
      table_mappings = jsonencode({
        rules = [
          {
            rule-type = "selection"
            rule-id   = "1"
            rule-name = "1"
            object-locator = {
              schema-name = "public"
              table-name  = "%"
            }
            rule-action = "include"
          }
        ]
      })
    }
  ]
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
  default     = "database_warehouse"
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

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
