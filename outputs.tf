output "product_events_queue_url" {
  description = "URL of the product events queue"
  value       = aws_sqs_queue.product_events_queue.url
}

output "product_events_queue_arn" {
  description = "ARN of the product events queue"
  value       = aws_sqs_queue.product_events_queue.arn
}

output "product_events_dlq_url" {
  description = "URL of the product events dead letter queue"
  value       = aws_sqs_queue.product_events_dlq.url
}

output "product_events_dlq_arn" {
  description = "ARN of the product events dead letter queue"
  value       = aws_sqs_queue.product_events_dlq.arn
}

# Lambda Function ARN
output "product_operations_lambda_arn" {
  description = "The ARN of the Lambda function for product operations"
  value       = aws_lambda_function.product_operations_lambda.arn
}

# API Gateway Invoke URL
output "product_operations_api_url" {
  description = "The URL to invoke the product operations API"
  value       = "${aws_apigatewayv2_api.product_operations_api.api_endpoint}/product-operations"
}

# API Gateway ID
output "product_operations_api_id" {
  description = "The ID of the API Gateway"
  value       = aws_apigatewayv2_api.product_operations_api.id
}
