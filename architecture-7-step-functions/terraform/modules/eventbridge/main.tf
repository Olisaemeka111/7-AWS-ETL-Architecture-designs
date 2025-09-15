# EventBridge Module for Step Functions ETL

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "rules" {
  for_each = var.rules

  name                = each.value.name
  description         = each.value.description
  schedule_expression = each.value.schedule_expression

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

# EventBridge Targets
resource "aws_cloudwatch_event_target" "targets" {
  for_each = {
    for rule_key, rule in var.rules : rule_key => rule
    if length(rule.targets) > 0
  }

  rule      = aws_cloudwatch_event_rule.rules[each.key].name
  target_id = each.value.targets[0].id
  arn       = each.value.targets[0].arn
  role_arn  = each.value.targets[0].role_arn

  dynamic "input" {
    for_each = each.value.targets[0].input != null ? [each.value.targets[0].input] : []
    content {
      input = input.value
    }
  }
}
