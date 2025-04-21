# Lambda to SQS Integration for Snackbar Management

This document explains how to use the Lambda function to produce SQS messages for product CRUD operations in the Snackbar Management system.

## Architecture Overview

The architecture consists of:

1. **AWS Lambda Function**: Processes product CRUD operations and sends messages to SQS
2. **SQS Queue**: Receives messages from the Lambda function
3. **Snackbar Management Application**: Consumes messages from the SQS queue

## Setup Instructions

### 1. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# For AWS deployment
terraform apply

# For LocalStack deployment
terraform apply -var="use_localstack=true"
```

### 2. Test the Lambda Function

Use the provided test scripts to send test messages to the Lambda function:

```bash
# For LocalStack with default sleep time (30 seconds)
./test_lambda.sh localstack

# For AWS with default sleep time (30 seconds)
./test_lambda.sh aws

# For AWS with custom sleep time (45 seconds)
./test_lambda.sh aws 45
```

Alternatively, use the sequential test script that properly handles MongoDB ObjectIds:

```bash
# For LocalStack with default sleep time (30 seconds)
./test_lambda_sequence.sh localstack

# For AWS with default sleep time (30 seconds)
./test_lambda_sequence.sh aws

# For AWS with custom sleep time (45 seconds)
./test_lambda_sequence.sh aws 45
```

The sequential script:
- Creates a product
- Retrieves the MongoDB ObjectId from the application
- Uses that ObjectId for subsequent UPDATE and DELETE operations
- Verifies each operation was successful

This script will:
- Send a CREATE operation to create a new product
- Wait for the specified sleep time to allow the application to process the message
- Send an UPDATE operation to update the product
- Wait for the specified sleep time to allow the application to process the message
- Send a DELETE operation to delete the product
- Wait for the specified sleep time to allow the application to process the message
- Check the SQS queue for messages

### 3. Verify Message Processing

The Snackbar Management application is configured to consume messages from the SQS queue. You can verify that messages are being processed by:

1. Checking the application logs:
```bash
docker-compose logs -f app
```

2. Looking for log entries from `SQSProductMessageConsumer` that indicate messages are being processed.

### 4. Understanding the Testing Process

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

## Message Format

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

## Lambda Function API

The Lambda function is exposed via API Gateway and accepts the following operations:

### Create Product

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

### Update Product

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

### Delete Product

```json
{
  "operation": "DELETE",
  "productId": "existing-product-id"
}
```

## Integration with Snackbar Management Application

To make the Snackbar Management application consume messages from this Lambda-produced SQS queue:

1. Ensure the `SQSProductMessageConsumer` class is annotated with both production and development profiles:

```java
@Component
@Profile({"prod", "dev"}) // Use in both production and development profiles
public class SQSProductMessageConsumer {
    // ...
}
```

2. Configure the application with the correct SQS queue URL:

```properties
# For LocalStack
aws.sqs.product-events-queue-url=http://localstack:4566/000000000000/product-events

# For AWS
aws.sqs.product-events-queue-url=https://sqs.us-east-1.amazonaws.com/953430082388/snackbar-management-product-events-queue
```

## Monitoring and Troubleshooting

### Monitoring Message Processing

To monitor the message processing in the snackbar-management application, you can check the logs:

```bash
cd /home/saulo/workspace/fiap-alura/fase04/snackbar-management
docker-compose logs app | grep -i "Processing"
```

Or to see received messages:

```bash
docker-compose logs app | grep -i "Received"
```

### SQS Consumer Not Processing Messages

If the SQS consumer is not processing messages, check:

1. The application is running with the correct profile (`dev` for LocalStack, `aws-local` for AWS)
2. The SQS queue URL is correctly configured in the application
3. The `SQSProductMessageConsumer` is active (it should be annotated with `@Profile({"aws-local", "dev"})`)
4. AWS credentials are properly mounted in the container (for aws-local profile)

### Lambda Function Not Sending Messages

If the Lambda function is not sending messages to SQS, check:

1. The Lambda function is correctly deployed
2. The SQS queue exists
3. The Lambda function has the correct environment variables set
4. The IAM role has the necessary permissions to send messages to SQS

You can check the Lambda logs in CloudWatch or LocalStack.
