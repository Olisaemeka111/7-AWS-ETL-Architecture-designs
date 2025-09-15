# S3 Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "buckets" {
  description = "Map of S3 buckets to create"
  type = map(object({
    name           = string
    versioning     = bool
    lifecycle_rules = list(object({
      id     = string
      status = string
      transitions = list(object({
        days          = number
        storage_class = string
      }))
    }))
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
