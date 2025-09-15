# CloudWatch Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to monitor"
  type        = list(string)
  default     = []
}

variable "glue_job_names" {
  description = "List of Glue job names to monitor"
  type        = list(string)
  default     = []
}

variable "emr_cluster_id" {
  description = "EMR cluster ID to monitor"
  type        = string
  default     = null
}

variable "redshift_cluster_identifier" {
  description = "Redshift cluster identifier to monitor"
  type        = string
  default     = null
}

variable "step_functions_state_machine_arn" {
  description = "Step Functions state machine ARN to monitor"
  type        = string
  default     = null
}

variable "sns_topic_arns" {
  description = "List of SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
