# EMR Module - Main Configuration

# EMR Service Role
resource "aws_iam_role" "emr_service_role" {
  name = "${var.project_name}-${var.environment}-emr-service-role"

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

  tags = var.tags
}

# EMR Service Role Policy
resource "aws_iam_role_policy_attachment" "emr_service_role_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# EMR Instance Profile Role
resource "aws_iam_role" "emr_instance_profile_role" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile-role"

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

  tags = var.tags
}

# EMR Instance Profile Role Policy
resource "aws_iam_role_policy_attachment" "emr_instance_profile_role_policy" {
  role       = aws_iam_role.emr_instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRforEC2Role"
}

# EMR Instance Profile
resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile"
  role = aws_iam_role.emr_instance_profile_role.name

  tags = var.tags
}

# S3 Access Policy for EMR
resource "aws_iam_role_policy" "emr_s3_access" {
  name = "${var.project_name}-${var.environment}-emr-s3-access"
  role = aws_iam_role.emr_instance_profile_role.id

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
          "arn:aws:s3:::${var.raw_data_bucket}",
          "arn:aws:s3:::${var.raw_data_bucket}/*",
          "arn:aws:s3:::${var.processed_data_bucket}",
          "arn:aws:s3:::${var.processed_data_bucket}/*",
          "arn:aws:s3:::${var.aggregated_data_bucket}",
          "arn:aws:s3:::${var.aggregated_data_bucket}/*",
          "arn:aws:s3:::${var.logs_bucket}",
          "arn:aws:s3:::${var.logs_bucket}/*"
        ]
      }
    ]
  })
}

# Glue Access Policy for EMR
resource "aws_iam_role_policy" "emr_glue_access" {
  name = "${var.project_name}-${var.environment}-emr-glue-access"
  role = aws_iam_role.emr_instance_profile_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs Policy for EMR
resource "aws_iam_role_policy" "emr_cloudwatch_logs" {
  name = "${var.project_name}-${var.environment}-emr-cloudwatch-logs"
  role = aws_iam_role.emr_instance_profile_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# EMR Security Group
resource "aws_security_group" "emr_security_group" {
  name_prefix = "${var.project_name}-${var.environment}-emr-"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Spark UI
  ingress {
    from_port   = 4040
    to_port     = 4040
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Spark History Server
  ingress {
    from_port   = 18080
    to_port     = 18080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # YARN Resource Manager
  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Hue
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Zeppelin
  ingress {
    from_port   = 8890
    to_port     = 8890
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-emr-security-group"
  })
}

# EMR Cluster
resource "aws_emr_cluster" "emr_cluster" {
  name          = var.cluster_name
  release_label = "emr-6.15.0"
  applications  = var.applications

  ec2_attributes {
    subnet_id                         = var.private_subnet_ids[0]
    emr_managed_master_security_group = aws_security_group.emr_security_group.id
    emr_managed_slave_security_group  = aws_security_group.emr_security_group.id
    instance_profile                  = aws_iam_instance_profile.emr_instance_profile.arn
    key_name                          = var.key_name
  }

  master_instance_group {
    instance_type = var.master_instance_type
    instance_count = 1
  }

  core_instance_group {
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count
  }

  dynamic "task_instance_group" {
    for_each = var.task_instance_count > 0 ? [1] : []
    content {
      instance_type  = var.task_instance_type
      instance_count = var.task_instance_count
      bid_price      = var.enable_spot_instances ? var.spot_bid_price : null
    }
  }

  # Auto-scaling configuration
  dynamic "auto_scaling_role" {
    for_each = var.enable_auto_scaling ? [1] : []
    content {
      iam_role = aws_iam_role.emr_autoscaling_role[0].arn
    }
  }

  # Bootstrap actions
  dynamic "bootstrap_action" {
    for_each = var.bootstrap_actions
    content {
      path = bootstrap_action.value.path
      name = bootstrap_action.value.name
      args = bootstrap_action.value.args
    }
  }

  # Steps
  dynamic "step" {
    for_each = var.steps
    content {
      action_on_failure = step.value.action_on_failure
      name              = step.value.name
      hadoop_jar_step {
        jar  = step.value.hadoop_jar_step.jar
        args = step.value.hadoop_jar_step.args
      }
    }
  }

  # Logging configuration
  log_uri = "s3://${var.logs_bucket}/emr-logs/"

  # Service role
  service_role = aws_iam_role.emr_service_role.arn

  # Configuration
  configurations_json = jsonencode([
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.sql.adaptive.enabled" = "true"
        "spark.sql.adaptive.coalescePartitions.enabled" = "true"
        "spark.serializer" = "org.apache.spark.serializer.KryoSerializer"
        "spark.sql.parquet.compression.codec" = "snappy"
        "spark.sql.parquet.mergeSchema" = "false"
      }
    },
    {
      Classification = "hive-site"
      Properties = {
        "hive.metastore.client.factory.class" = "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
      }
    }
  ])

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.emr_s3_access,
    aws_iam_role_policy.emr_glue_access,
    aws_iam_role_policy.emr_cloudwatch_logs
  ]
}

# EMR Auto-scaling Role
resource "aws_iam_role" "emr_autoscaling_role" {
  count = var.enable_auto_scaling ? 1 : 0
  name  = "${var.project_name}-${var.environment}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# EMR Auto-scaling Role Policy
resource "aws_iam_role_policy_attachment" "emr_autoscaling_role_policy" {
  count      = var.enable_auto_scaling ? 1 : 0
  role       = aws_iam_role.emr_autoscaling_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRforAutoScalingRole"
}

# EMR Auto-scaling Target
resource "aws_appautoscaling_target" "emr_autoscaling_target" {
  count              = var.enable_auto_scaling ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "instancegroup/${aws_emr_cluster.emr_cluster.id}/TASK"
  scalable_dimension = "elasticmapreduce:instancegroup:InstanceCount"
  service_namespace  = "elasticmapreduce"

  depends_on = [aws_emr_cluster.emr_cluster]
}

# EMR Auto-scaling Policy - Scale Out
resource "aws_appautoscaling_policy" "emr_scale_out" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-emr-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.emr_autoscaling_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.emr_autoscaling_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.emr_autoscaling_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "EMRTaskNodeCPUUtilization"
    }
    target_value = 75.0
    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }
}

# EMR Auto-scaling Policy - Scale In
resource "aws_appautoscaling_policy" "emr_scale_in" {
  count              = var.enable_auto_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-emr-scale-in"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.emr_autoscaling_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.emr_autoscaling_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.emr_autoscaling_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "EMRTaskNodeCPUUtilization"
    }
    target_value = 25.0
    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }
}
