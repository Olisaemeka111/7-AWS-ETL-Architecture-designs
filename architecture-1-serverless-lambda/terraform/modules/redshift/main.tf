# Redshift Module for Serverless ETL Architecture

# Random password for Redshift
resource "random_password" "redshift_password" {
  length  = 16
  special = true
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "redshift_password" {
  name = "${var.project_name}-${var.environment}-redshift-password"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redshift_password" {
  secret_id = aws_secretsmanager_secret.redshift_password.id
  secret_string = jsonencode({
    username = "etl_user"
    password = random_password.redshift_password.result
  })
}

# Redshift Subnet Group
resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redshift-subnet-group"
  })
}

# Redshift Parameter Group
resource "aws_redshift_parameter_group" "main" {
  family = "redshift-1.0"
  name   = "${var.project_name}-${var.environment}-redshift-params"

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_connections"
    value = "true"
  }

  tags = var.tags
}

# Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-warehouse"

  # Database
  database_name   = "etl_warehouse"
  master_username = "etl_user"
  master_password = random_password.redshift_password.result

  # Node configuration
  node_type             = "dc2.large"
  number_of_nodes       = 1
  cluster_type          = "single-node"

  # Network
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  vpc_security_group_ids    = var.security_group_ids
  publicly_accessible      = false

  # Storage
  encrypted = true

  # Backup
  automated_snapshot_retention_period = 7
  preferred_maintenance_window       = "sun:04:00-sun:05:00"

  # Monitoring
  cluster_parameter_group_name = aws_redshift_parameter_group.main.name

  # Deletion protection
  skip_final_snapshot = true
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  tags = var.tags
}

# IAM Role for Redshift to access S3
resource "aws_iam_role" "redshift_s3" {
  name = "${var.project_name}-${var.environment}-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "redshift_s3" {
  name = "${var.project_name}-${var.environment}-redshift-s3-policy"
  role = aws_iam_role.redshift_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.staging_bucket_name}",
          "arn:aws:s3:::${var.staging_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach the role to the cluster
resource "aws_redshift_cluster_iam_roles" "main" {
  cluster_identifier = aws_redshift_cluster.main.cluster_identifier
  iam_role_arns      = [aws_iam_role.redshift_s3.arn]
}
