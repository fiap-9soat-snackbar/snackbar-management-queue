# Snackbar Management Queue Module

This Terraform module creates the necessary SQS queues for the Snackbar Management application's product module.

## Resources Created

- **Product Events Queue**: Main queue for product-related events (creation, updates, deletions)
- **Product Events Dead Letter Queue (DLQ)**: Queue for messages that fail processing

## Usage

```hcl
module "snackbar_management_queue" {
  source = "./snackbar-management-queue"
  
  # Optional: Override default values
  max_receive_count = 5
  message_retention_seconds = 345600  # 4 days
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| max_receive_count | Maximum number of times a message can be received before being sent to the DLQ | number | 5 | no |
| message_retention_seconds | The number of seconds SQS retains a message | number | 345600 (4 days) | no |
| visibility_timeout_seconds | The visibility timeout for the queue | number | 30 | no |
| delay_seconds | The time in seconds that the delivery of all messages in the queue will be delayed | number | 0 | no |
| receive_wait_time_seconds | The time for which a ReceiveMessage call will wait for a message to arrive | number | 0 | no |
| max_message_size | The limit of how many bytes a message can contain | number | 262144 (256 KiB) | no |

## Outputs

| Name | Description |
|------|-------------|
| product_events_queue_url | URL of the product events queue |
| product_events_queue_arn | ARN of the product events queue |
| product_events_dlq_url | URL of the product events dead letter queue |
| product_events_dlq_arn | ARN of the product events dead letter queue |

## Integration with Snackbar Management Application

This module creates the SQS infrastructure required by the Snackbar Management application's product module. The application uses these queues to publish domain events when products are created, updated, or deleted.

To connect the application to these queues, update the application's configuration with the queue URLs from this module's outputs.

Example application.properties configuration:

```properties
aws.region=us-east-1
aws.sqs.product-events-queue-url=${product_events_queue_url}
```
