# ---------------------------------------------------------------------------
# VPC Flow Logs to CloudWatch. The IAM role is created in-module unless an
# external role ARN is provided.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_338:Retention is configurable via flow_logs_retention_days; the 30-day default balances cost. Set 365+ where compliance requires it.
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc-flow-logs/${local.vpc_name}"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_id

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.vpc_name}-flow-logs"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_role_arn == null ? 1 : 0

  name = "${local.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_role_arn == null ? 1 : 0

  name = "${local.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = var.flow_logs_traffic_type
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn    = coalesce(var.flow_logs_role_arn, try(aws_iam_role.flow_logs[0].arn, null))

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.vpc_name}-flow-logs"
      Environment = var.environment
    }
  )
}
