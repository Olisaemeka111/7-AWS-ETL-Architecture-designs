# EMR Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "enabled" {
  description = "Whether to create EMR cluster"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EMR cluster"
  type        = string
}

variable "release_label" {
  description = "EMR release label"
  type        = string
}

variable "applications" {
  description = "List of EMR applications"
  type        = list(string)
}

variable "master_instance_type" {
  description = "Master instance type"
  type        = string
}

variable "core_instance_type" {
  description = "Core instance type"
  type        = string
}

variable "core_instance_count" {
  description = "Number of core instances"
  type        = number
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "logs_bucket" {
  description = "S3 bucket for EMR logs"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
