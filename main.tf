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
#--------------------------------------------------------------
# Lambda Function for Product Operations
#--------------------------------------------------------------
/*
# Create a zip file of the Lambda function code
data "archive_file" "product_operations_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/product_operations"
  output_path = "${path.module}/lambda/product_operations.zip"
}

# Lambda function
resource "aws_lambda_function" "product_operations_lambda" {
  function_name    = "${local.project_name}-product-operations"
  description      = "Lambda function to produce SQS messages for product CRUD operations"
  role             = "arn:aws:iam::${var.aws_account_id}:role/LabRole"  # Using existing LabRole
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.product_operations_lambda_zip.output_path
  source_code_hash = data.archive_file.product_operations_lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SQS_QUEUE_URL    = aws_sqs_queue.product_events_queue.url
    }
  }

  tags = {
    Name        = "${local.project_name}-product-operations"
    Environment = local.environment
    Project     = local.project_name
  }
}

# CloudWatch Log Group for the Lambda function
resource "aws_cloudwatch_log_group" "product_operations_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.product_operations_lambda.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.project_name}-product-operations-logs"
    Environment = local.environment
    Project     = local.project_name
  }
}

# API Gateway to expose the Lambda function
resource "aws_apigatewayv2_api" "product_operations_api" {
  name          = "${local.project_name}-product-operations-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name        = "${local.project_name}-product-operations-api"
    Environment = local.environment
    Project     = local.project_name
  }
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "product_operations_api_stage" {
  api_id      = aws_apigatewayv2_api.product_operations_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.product_operations_api_log_group.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      path           = "$context.path"
    })
  }

  tags = {
    Name        = "${local.project_name}-product-operations-api-stage"
    Environment = local.environment
    Project     = local.project_name
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "product_operations_api_log_group" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.product_operations_api.name}"
  retention_in_days = 14

  tags = {
    Name        = "${local.project_name}-product-operations-api-logs"
    Environment = local.environment
    Project     = local.project_name
  }
}

# API Gateway integration with Lambda
resource "aws_apigatewayv2_integration" "product_operations_api_integration" {
  api_id                 = aws_apigatewayv2_api.product_operations_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.product_operations_lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# API Gateway route
resource "aws_apigatewayv2_route" "product_operations_api_route" {
  api_id    = aws_apigatewayv2_api.product_operations_api.id
  route_key = "POST /product-operations"
  target    = "integrations/${aws_apigatewayv2_integration.product_operations_api_integration.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "product_operations_api_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.product_operations_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.product_operations_api.execution_arn}\/*\/*\/product-operations"
}
*/