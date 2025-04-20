#--------------------------------------------------------------
# SQS Queue Resources for Snackbar Management - Product Module
#--------------------------------------------------------------

# Product Events Queue
resource "aws_sqs_queue" "product_events_queue" {
  name                       = "${local.project_name}-product-events-queue"
  fifo_queue                 = false
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  tags = {
    Name        = "${local.project_name}-product-events-queue"
    Environment = local.environment
    Project     = local.project_name
  }
}

# Product Events Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "product_events_dlq" {
  name                      = "${local.project_name}-product-events-dlq"
  fifo_queue                = false
  message_retention_seconds = var.message_retention_seconds
  
  tags = {
    Name        = "${local.project_name}-product-events-dlq"
    Environment = local.environment
    Project     = local.project_name
  }
}

#--------------------------------------------------------------
# Queue Policies
#--------------------------------------------------------------

# Product Events Queue Policy
resource "aws_sqs_queue_policy" "product_events_queue_policy" {
  queue_url = aws_sqs_queue.product_events_queue.id
  policy = templatefile("${path.module}/policies/main_queue_policy_template.json", {
    queue_name = aws_sqs_queue.product_events_queue.name,
    queue_arn  = aws_sqs_queue.product_events_queue.arn
  })
}

# Product Events DLQ Policy
resource "aws_sqs_queue_policy" "product_events_dlq_policy" {
  queue_url = aws_sqs_queue.product_events_dlq.id
  policy = templatefile("${path.module}/policies/dlq_policy_template.json", {
    queue_name       = aws_sqs_queue.product_events_dlq.name,
    queue_arn        = aws_sqs_queue.product_events_dlq.arn,
    source_queue_arn = aws_sqs_queue.product_events_queue.arn
  })
}

#--------------------------------------------------------------
# Redrive Policies
#--------------------------------------------------------------

# Redrive policy for the Product Events queue
resource "aws_sqs_queue_redrive_policy" "product_events_queue_redrive_policy" {
  queue_url = aws_sqs_queue.product_events_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_events_dlq.arn
    maxReceiveCount     = jsondecode(file("${path.module}/policies/redrive_policy.json")).maxReceiveCount
  })
}

# Redrive allow policy for the Product Events DLQ
resource "aws_sqs_queue_redrive_allow_policy" "product_events_dlq_redrive_allow_policy" {
  queue_url = aws_sqs_queue.product_events_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = jsondecode(file("${path.module}/policies/dlq_allow_policy.json")).redrivePermission
    sourceQueueArns   = [aws_sqs_queue.product_events_queue.arn]
  })
}
