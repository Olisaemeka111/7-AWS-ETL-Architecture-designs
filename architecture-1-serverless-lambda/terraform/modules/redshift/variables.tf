# Redshift Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Redshift cluster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Redshift cluster"
  type        = list(string)
}

variable "logs_bucket_name" {
  description = "S3 bucket name for Redshift logs"
  type        = string
}

variable "staging_bucket_name" {
  description = "S3 bucket name for staging data"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
