# SNS Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "topics" {
  description = "Map of SNS topics to create"
  type = map(object({
    name         = string
    display_name = string
    subscriptions = list(object({
      protocol = string
      endpoint = string
    }))
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
