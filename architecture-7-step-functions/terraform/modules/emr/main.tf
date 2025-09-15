# EMR Module (Optional)

resource "aws_emr_cluster" "cluster" {
  count = var.enabled ? 1 : 0

  name          = var.cluster_name
  release_label = var.release_label
  applications  = var.applications

  ec2_attributes {
    subnet_id                         = var.private_subnet_ids[0]
    emr_managed_master_security_group = var.security_group_ids[0]
    emr_managed_slave_security_group  = var.security_group_ids[0]
    instance_profile                  = aws_iam_instance_profile.emr_profile[0].arn
  }

  master_instance_group {
    instance_type = var.master_instance_type
  }

  core_instance_group {
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count
  }

  log_uri = "s3://${var.logs_bucket}/emr-logs/"

  service_role = aws_iam_role.emr_service_role[0].arn

  tags = var.tags
}

resource "aws_iam_instance_profile" "emr_profile" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-emr-profile"
  role  = aws_iam_role.emr_ec2_role[0].name
}

resource "aws_iam_role" "emr_service_role" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "emr_ec2_role" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
