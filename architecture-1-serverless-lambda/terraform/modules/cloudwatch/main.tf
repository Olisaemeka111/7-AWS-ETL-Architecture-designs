# CloudWatch Module - Main Configuration

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset(var.lambda_function_names)
  
  name              = "/aws/lambda/${each.key}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "etl_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-etl-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Invocations", "FunctionName", func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Errors", "FunctionName", func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Duration", "FunctionName", func_name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfVisibleMessages", "QueueName", var.sqs_queue_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SQS Queue Depth"
          period  = 300
        }
      }
    ]
  })
  
  tags = var.tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)
  
  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors for ${each.key}"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = each.key
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = toset(var.lambda_function_names)
  
  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "300000"  # 5 minutes in milliseconds
  alarm_description   = "This metric monitors lambda duration for ${each.key}"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = each.key
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "This metric monitors SQS queue depth"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    QueueName = var.sqs_queue_name
  }
  
  tags = var.tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.alert_emails)
  
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# Custom Metrics
resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  for_each = toset(var.lambda_function_names)
  
  name           = "${var.project_name}-${var.environment}-${each.key}-error-filter"
  log_group_name = aws_cloudwatch_log_group.lambda_logs[each.key].name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"
  
  metric_transformation {
    name      = "${each.key}ErrorCount"
    namespace = "ETL/Lambda"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "lambda_warnings" {
  for_each = toset(var.lambda_function_names)
  
  name           = "${var.project_name}-${var.environment}-${each.key}-warning-filter"
  log_group_name = aws_cloudwatch_log_group.lambda_logs[each.key].name
  pattern        = "[timestamp, request_id, level=\"WARNING\", ...]"
  
  metric_transformation {
    name      = "${each.key}WarningCount"
    namespace = "ETL/Lambda"
    value     = "1"
  }
}
