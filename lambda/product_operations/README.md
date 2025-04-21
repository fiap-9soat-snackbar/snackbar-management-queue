# Product Operations Lambda Function

This Lambda function produces SQS messages for product CRUD operations in the Snackbar Management system.

## Overview

The function accepts requests to create, update, or delete products and sends appropriately formatted messages to an SQS queue. These messages are then consumed by the Snackbar Management application to perform the actual operations.

## Message Format

Messages are sent in JSON format with the following structure:

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

For delete operations, only the `productId` field is required (along with the standard message fields).

## Usage

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

## Environment Variables

- `SQS_QUEUE_URL`: URL of the SQS queue to send messages to
- `SQS_ENDPOINT_URL`: (Optional) Custom endpoint URL for SQS (used for LocalStack)
- `AWS_REGION`: AWS region (defaults to us-east-1)

## Error Handling

The function performs validation on the input data and returns appropriate error messages if validation fails. It also handles exceptions that may occur during processing and returns meaningful error messages.

## Response Format

All responses follow this format:

```json
{
  "statusCode": 200|400|500,
  "body": {
    "success": true|false,
    "message": "Human readable message",
    "data": {
      "productId": "product-id",
      "sqsMessageId": "sqs-message-id"
    }
  }
}
```
