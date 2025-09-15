# Glue Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
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

variable "iam_role_arn" {
  description = "ARN of the IAM role for Glue execution"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
