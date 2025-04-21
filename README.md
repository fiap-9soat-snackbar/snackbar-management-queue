# Snackbar Management Queue

This repository contains the infrastructure as code (Terraform) for the SQS queues and Lambda functions used by the Snackbar Management system.

## Architecture

The architecture consists of:

1. **SQS Queues**:
   - `product-events-queue`: Main queue for product events
   - `product-events-dlq`: Dead letter queue for failed messages

2. **Lambda Function**:
   - `product-operations`: Processes product CRUD operations and sends messages to SQS

3. **API Gateway**:
   - HTTP API that exposes the Lambda function

## Deployment

### Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials
- For local development: Docker and LocalStack

### AWS Deployment

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Plan the deployment:
   ```
   terraform plan
   ```

3. Apply the changes:
   ```
   terraform apply
   ```

### LocalStack Deployment

1. Start LocalStack:
   ```
   docker run -d -p 4566:4566 -p 4571:4571 --name localstack localstack/localstack
   ```

2. Initialize Terraform with LocalStack provider:
   ```
   terraform init
   ```

3. Apply the changes with LocalStack variable:
   ```
   terraform apply -var="use_localstack=true"
   ```

## Usage

### Sending Messages to SQS

The Lambda function accepts the following operations:

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

## Environment Support

This infrastructure is designed to work in both AWS and LocalStack environments:

- **AWS**: Uses real AWS services with proper IAM roles and permissions
- **LocalStack**: Uses LocalStack for local development and testing

The `use_localstack` variable controls which environment to target.

## IAM Roles

The Lambda function uses the existing `LabRole` (arn:aws:iam::953430082388:role/LabRole) which already has the necessary permissions for:

- Sending messages to SQS
- Writing logs to CloudWatch
- Executing Lambda functions

## Outputs

After deployment, the following outputs are available:

- `product_events_queue_url`: URL of the SQS queue
- `product_operations_api_url`: URL to invoke the API Gateway endpoint
- `localstack_sqs_queue_url`: LocalStack URL of the SQS queue (when using LocalStack)
