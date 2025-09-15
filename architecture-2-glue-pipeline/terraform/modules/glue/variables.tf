# Glue Module - Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "raw_zone_bucket" {
  description = "Name of the raw zone S3 bucket"
  type        = string
}

variable "clean_zone_bucket" {
  description = "Name of the clean zone S3 bucket"
  type        = string
}

variable "aggregated_zone_bucket" {
  description = "Name of the aggregated zone S3 bucket"
  type        = string
}

variable "temp_zone_bucket" {
  description = "Name of the temp zone S3 bucket"
  type        = string
}

variable "logs_zone_bucket" {
  description = "Name of the logs zone S3 bucket"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Glue connections"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "glue_jobs" {
  description = "Map of Glue jobs to create"
  type = map(object({
    name         = string
    script_path  = string
    max_capacity = number
    timeout      = number
    glue_version = string
  }))
}

variable "crawlers" {
  description = "Map of Glue crawlers to create"
  type = map(object({
    name          = string
    database_name = string
    s3_targets    = list(string)
    schedule      = string
  }))
}

variable "source_databases" {
  description = "List of source databases for connections"
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

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
