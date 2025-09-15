# Lambda Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda functions"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda functions"
  type        = list(string)
}

variable "source_rds_endpoint" {
  description = "RDS endpoint for data extraction"
  type        = string
}

variable "target_redshift_endpoint" {
  description = "Redshift endpoint for data loading"
  type        = string
}

variable "staging_bucket_name" {
  description = "S3 bucket name for staging data"
  type        = string
}

variable "staging_bucket_arn" {
  description = "S3 bucket ARN for staging data"
  type        = string
}

variable "processing_queue_url" {
  description = "SQS queue URL for processing messages"
  type        = string
}

variable "processing_queue_arn" {
  description = "SQS queue ARN for processing messages"
  type        = string
}

variable "dlq_url" {
  description = "Dead letter queue URL"
  type        = string
}

variable "dlq_arn" {
  description = "Dead letter queue ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
