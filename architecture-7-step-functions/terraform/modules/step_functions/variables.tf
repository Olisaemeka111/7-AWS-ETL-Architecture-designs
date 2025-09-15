# Step Functions Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "state_machine" {
  description = "Step Functions state machine configuration"
  type = object({
    name       = string
    definition = string
  })
}

variable "execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
