#--------------------------------------------------------------
# LocalStack Configuration
#--------------------------------------------------------------

# This file contains configuration specific to LocalStack for local development

# Provider configuration for LocalStack
provider "aws" {
  alias                   = "localstack"
  region                  = local.region
  access_key              = "test"
  secret_key              = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # LocalStack endpoint configuration
  endpoints {
    apigateway     = "http://localhost:4566"
    apigatewayv2   = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    sqs            = "http://localhost:4566"
  }
}

# Outputs specific to LocalStack
output "localstack_sqs_queue_url" {
  description = "The URL of the SQS queue in LocalStack"
  value       = var.use_localstack ? replace(aws_sqs_queue.product_events_queue.url, "amazonaws.com", "localhost:4566") : null
}

output "localstack_lambda_invoke_url" {
  description = "The URL to invoke the Lambda function in LocalStack"
  value       = var.use_localstack ? "http://localhost:4566/2015-03-31/functions/${aws_lambda_function.product_operations_lambda.function_name}/invocations" : null
}

output "localstack_api_gateway_url" {
  description = "The URL of the API Gateway in LocalStack"
  value       = var.use_localstack ? "http://localhost:4566/restapis/${aws_apigatewayv2_api.product_operations_api.id}/stages/${aws_apigatewayv2_stage.product_operations_api_stage.name}/product-operations" : null
}
