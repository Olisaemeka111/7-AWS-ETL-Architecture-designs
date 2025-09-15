# EventBridge Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "rules" {
  description = "Map of EventBridge rules to create"
  type = map(object({
    name                = string
    description         = string
    schedule_expression = string
    targets = list(object({
      id       = string
      arn      = string
      role_arn = string
      input    = optional(string)
    }))
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
