# Lambda Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "functions" {
  description = "Map of Lambda functions to create"
  type = map(object({
    name                 = string
    handler              = string
    runtime              = string
    timeout              = number
    memory_size          = number
    source_path          = string
    environment_variables = map(string)
  }))
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda functions"
  type        = list(string)
}

variable "iam_role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
