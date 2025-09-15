# EMR Module - Variables

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

# S3 Configuration
variable "raw_data_bucket" {
  description = "Name of the raw data S3 bucket"
  type        = string
}

variable "processed_data_bucket" {
  description = "Name of the processed data S3 bucket"
  type        = string
}

variable "aggregated_data_bucket" {
  description = "Name of the aggregated data S3 bucket"
  type        = string
}

variable "logs_bucket" {
  description = "Name of the logs S3 bucket"
  type        = string
}

# VPC Configuration
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs of the security groups"
  type        = list(string)
  default     = []
}

# EMR Cluster Configuration
variable "cluster_name" {
  description = "Name of the EMR cluster"
  type        = string
}

variable "master_instance_type" {
  description = "EC2 instance type for EMR master node"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  description = "EC2 instance type for EMR core nodes"
  type        = string
  default     = "m5.large"
}

variable "core_instance_count" {
  description = "Number of core instances in the EMR cluster"
  type        = number
  default     = 2
}

variable "task_instance_type" {
  description = "EC2 instance type for EMR task nodes"
  type        = string
  default     = "m5.large"
}

variable "task_instance_count" {
  description = "Number of task instances in the EMR cluster"
  type        = number
  default     = 0
}

# Auto-scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable auto-scaling for EMR cluster"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of task instances for auto-scaling"
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Maximum number of task instances for auto-scaling"
  type        = number
  default     = 20
}

# Spot Instance Configuration
variable "enable_spot_instances" {
  description = "Enable spot instances for task nodes"
  type        = bool
  default     = true
}

variable "spot_bid_price" {
  description = "Bid price for spot instances"
  type        = string
  default     = "0.10"
}

# Applications
variable "applications" {
  description = "List of applications to install on EMR cluster"
  type        = list(string)
  default     = ["Spark", "Hadoop", "Hive", "Pig", "Hue", "Zeppelin"]
}

# Bootstrap Actions
variable "bootstrap_actions" {
  description = "List of bootstrap actions for EMR cluster"
  type = list(object({
    name = string
    path = string
    args = list(string)
  }))
  default = []
}

# Steps
variable "steps" {
  description = "List of EMR steps to execute"
  type = list(object({
    name              = string
    action_on_failure = string
    hadoop_jar_step = object({
      jar  = string
      args = list(string)
    })
  }))
  default = []
}

# Key Pair
variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
