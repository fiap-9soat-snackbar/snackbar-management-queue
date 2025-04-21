# Snackbar Management Queue

This repository contains the infrastructure as code (Terraform) for the SQS queues and Lambda functions used by the Snackbar Management system.

## Architecture Overview

The architecture consists of:

1. **SQS Queues**:
   - `product-events-queue`: Main queue for product events
   - `product-events-dlq`: Dead letter queue for failed messages

2. **Lambda Function**:
   - `product-operations`: Processes product CRUD operations and sends messages to SQS

3. **API Gateway**:
   - HTTP API that exposes the Lambda function

4. **Snackbar Management Application**: 
   - Consumes messages from the SQS queue

## Deployment

### Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials

### AWS Deployment

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the deployment:
   ```bash
   terraform plan
   ```

3. Apply the changes:
   ```bash
   terraform apply
   ```

## Usage

### Lambda Function API

The Lambda function is exposed via API Gateway and accepts the following operations:

#### Create Product

```json
{
  "operation": "CREATE",
  "product": {
    "name": "Cheeseburger",
    "category": "Lanche",
    "description": "Delicious cheeseburger with special sauce",
    "price": 12.99,
    "cookingTime": 10
  }
}
```

#### Update Product

```json
{
  "operation": "UPDATE",
  "productId": "existing-product-id",
  "product": {
    "name": "Cheeseburger Deluxe",
    "category": "Lanche",
    "description": "Delicious cheeseburger with special sauce and extra cheese",
    "price": 14.99,
    "cookingTime": 12
  }
}
```

#### Delete Product

```json
{
  "operation": "DELETE",
  "productId": "existing-product-id"
}
```

### Message Format

Messages sent to SQS have the following format:

```json
{
  "messageId": "uuid-string",
  "eventType": "PRODUCT_CREATED|PRODUCT_UPDATED|PRODUCT_DELETED",
  "timestamp": 1745202664.371865219,
  "productId": "product-id",
  "name": "Product Name",
  "category": "Category",
  "description": "Description",
  "price": 9.99,
  "cookingTime": 5
}
```

## Testing

Use the `test_lambda_sequence.sh` script to test the Lambda function and SQS integration:

```bash
./test_lambda_sequence.sh [SLEEP_TIME]
```

Where `SLEEP_TIME` is an optional parameter specifying how long to wait between operations (default: 30 seconds).

The sequential script:
- Creates a product
- Retrieves the MongoDB ObjectId from the application
- Uses that ObjectId for subsequent UPDATE and DELETE operations
- Verifies each operation was successful

### Understanding the Testing Process

The test script performs the following steps:

1. **CREATE Operation**:
   - Sends a request to create a new product
   - Waits for the specified sleep time to allow the application to process the message

2. **UPDATE Operation**:
   - Sends a request to update the previously created product
   - Waits for the specified sleep time to allow the application to process the message

3. **DELETE Operation**:
   - Sends a request to delete the product
   - Waits for the specified sleep time to allow the application to process the message

4. **Check SQS Messages**:
   - Retrieves any remaining messages from the SQS queue

The sleep time between operations is important because it allows the snackbar-management application enough time to process each message before proceeding to the next operation.

## Integration with Snackbar Management Application

To make the Snackbar Management application consume messages from this Lambda-produced SQS queue:

1. Ensure the `SQSProductMessageConsumer` class is annotated with the appropriate profile:

```java
@Component
@Profile({"prod", "dev"}) // Use in both production and development profiles
public class SQSProductMessageConsumer {
    // ...
}
```

2. Configure the application with the correct SQS queue URL:

```properties
aws.sqs.product-events-queue-url=https://sqs.us-east-1.amazonaws.com/953430082388/snackbar-management-product-events-queue
```

## Monitoring and Troubleshooting

### Monitoring Message Processing

To monitor the message processing in the snackbar-management application, you can check the logs:

```bash
docker-compose logs app | grep -i "Processing"
```

Or to see received messages:

```bash
docker-compose logs app | grep -i "Received"
```

### SQS Consumer Not Processing Messages

If the SQS consumer is not processing messages, check:

1. The application is running with the correct profile
2. The SQS queue URL is correctly configured in the application
3. The `SQSProductMessageConsumer` is active
4. AWS credentials are properly mounted in the container

### Lambda Function Not Sending Messages

If the Lambda function is not sending messages to SQS, check:

1. The Lambda function is correctly deployed
2. The SQS queue exists
3. The Lambda function has the correct environment variables set
4. The IAM role has the necessary permissions to send messages to SQS

## IAM Roles

The Lambda function uses the existing `LabRole` (arn:aws:iam::953430082388:role/LabRole) which already has the necessary permissions for:

- Sending messages to SQS
- Writing logs to CloudWatch
- Executing Lambda functions

## Outputs

After deployment, the following outputs are available:

- `product_events_queue_url`: URL of the SQS queue
- `product_operations_api_url`: URL to invoke the API Gateway endpoint
