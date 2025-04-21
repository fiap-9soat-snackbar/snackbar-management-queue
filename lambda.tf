#--------------------------------------------------------------
# Lambda Function for Product Operations
#--------------------------------------------------------------

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
  role             = "arn:aws:iam::953430082388:role/LabRole"  # Using existing LabRole
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.product_operations_lambda_zip.output_path
  source_code_hash = data.archive_file.product_operations_lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SQS_QUEUE_URL    = aws_sqs_queue.product_events_queue.url
      SQS_ENDPOINT_URL = var.use_localstack ? "http://localhost:4566" : null
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
  source_arn    = "${aws_apigatewayv2_api.product_operations_api.execution_arn}/*/*/product-operations"
}
