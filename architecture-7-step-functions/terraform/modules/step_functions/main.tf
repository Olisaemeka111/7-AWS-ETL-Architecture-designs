# Step Functions Module

resource "aws_sfn_state_machine" "state_machine" {
  name     = var.state_machine.name
  role_arn = var.execution_role_arn

  definition = var.state_machine.definition

  tags = var.tags
}
