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
