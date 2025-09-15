# Redshift Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Redshift cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "cluster_identifier" {
  description = "Redshift cluster identifier"
  type        = string
}

variable "node_type" {
  description = "Redshift node type"
  type        = string
  default     = "dc2.large"
}

variable "number_of_nodes" {
  description = "Number of nodes in the Redshift cluster"
  type        = number
  default     = 1
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "etldb"
}

variable "master_username" {
  description = "Master username for Redshift cluster"
  type        = string
  default     = "etluser"
}

variable "master_password" {
  description = "Master password for Redshift cluster"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
