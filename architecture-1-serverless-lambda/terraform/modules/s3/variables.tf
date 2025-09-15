# S3 Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "transform_lambda_arn" {
  description = "ARN of the transform Lambda function"
  type        = string
  default     = ""
}

variable "transform_lambda_name" {
  description = "Name of the transform Lambda function"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
