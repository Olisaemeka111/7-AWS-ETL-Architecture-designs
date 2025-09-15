# IAM Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs"
  type        = list(string)
  default     = []
}

variable "lambda_function_arns" {
  description = "List of Lambda function ARNs"
  type        = list(string)
  default     = []
}

variable "glue_job_arns" {
  description = "List of Glue job ARNs"
  type        = list(string)
  default     = []
}

variable "emr_cluster_arn" {
  description = "EMR cluster ARN"
  type        = string
  default     = null
}

variable "redshift_cluster_arn" {
  description = "Redshift cluster ARN"
  type        = string
  default     = null
}

variable "step_functions_state_machine_arn" {
  description = "Step Functions state machine ARN"
  type        = string
  default     = null
}

variable "sns_topic_arns" {
  description = "List of SNS topic ARNs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
