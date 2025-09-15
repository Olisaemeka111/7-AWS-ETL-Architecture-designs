# Redshift Module for Step Functions ETL

# Redshift Subnet Group
resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redshift-subnet-group"
  })
}

# Redshift Security Group
resource "aws_security_group" "redshift" {
  name_prefix = "${var.project_name}-${var.environment}-redshift-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redshift-sg"
  })
}

# Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier = var.cluster_identifier
  node_type          = var.node_type
  number_of_nodes    = var.number_of_nodes

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = merge(var.tags, {
    Name = var.cluster_identifier
  })
}

# Redshift Parameter Group
resource "aws_redshift_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-redshift-params"
  family = "redshift-1.0"

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redshift-params"
  })
}
