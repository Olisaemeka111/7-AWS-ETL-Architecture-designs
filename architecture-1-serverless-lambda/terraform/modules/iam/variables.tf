# IAM Module - Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "lambda_function_arns" {
  description = "List of Lambda function ARNs for EventBridge/SQS access"
  type        = list(string)
  default     = []
}

variable "rds_db_arns" {
  description = "List of RDS database ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "redshift_cluster_arns" {
  description = "List of Redshift cluster ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "enable_vpc_access" {
  description = "Enable VPC access for Lambda functions"
  type        = bool
  default     = false
}

variable "enable_rds_access" {
  description = "Enable RDS access for Lambda functions"
  type        = bool
  default     = false
}

variable "enable_redshift_access" {
  description = "Enable Redshift access for Lambda functions"
  type        = bool
  default     = false
}

variable "enable_sqs_event_source" {
  description = "Enable SQS as event source for Lambda"
  type        = bool
  default     = false
}

variable "enable_api_gateway" {
  description = "Enable API Gateway integration"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
