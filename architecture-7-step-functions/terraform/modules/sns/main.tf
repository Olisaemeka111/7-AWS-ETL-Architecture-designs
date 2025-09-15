# SNS Module for Step Functions ETL

# SNS Topics
resource "aws_sns_topic" "topics" {
  for_each = var.topics

  name         = each.value.name
  display_name = each.value.display_name

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "subscriptions" {
  for_each = {
    for topic_key, topic in var.topics : topic_key => topic
    if length(topic.subscriptions) > 0
  }

  topic_arn = aws_sns_topic.topics[each.key].arn
  protocol  = each.value.subscriptions[0].protocol
  endpoint  = each.value.subscriptions[0].endpoint
}
