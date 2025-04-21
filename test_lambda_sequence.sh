#!/bin/bash
# Script to test the product operations Lambda function with a proper sequence
# This script first creates a product, gets the MongoDB ObjectId from the logs,
# then uses that ID for update and delete operations

# Set environment variables
ENV=${1:-"localstack"}  # Default to localstack if no argument provided
SLEEP_TIME=${2:-30}     # Default sleep time between operations (in seconds)

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing Product Operations Lambda in $ENV environment${NC}"
echo -e "${YELLOW}Using sleep time of $SLEEP_TIME seconds between operations${NC}"

# Set the API endpoint based on environment
if [ "$ENV" == "localstack" ]; then
  # Get the LocalStack API Gateway URL
  API_URL=$(terraform output -raw localstack_api_gateway_url)
  echo -e "${YELLOW}Using LocalStack API URL: $API_URL${NC}"
else
  # Get the real AWS API Gateway URL
  API_URL=$(terraform output -raw product_operations_api_url)
  echo -e "${YELLOW}Using AWS API URL: $API_URL${NC}"
fi

# Test CREATE operation
echo -e "\n${GREEN}Testing CREATE operation${NC}"
CREATE_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "CREATE",
    "product": {
      "name": "Test Burger",
      "category": "Lanche",
      "description": "A delicious test burger with cheese",
      "price": 15.99,
      "cookingTime": 8
    }
  }' \
  $API_URL)

echo "Response: $CREATE_RESPONSE"

# Wait for the product to be created in the database
echo -e "${YELLOW}Waiting for product creation to be processed ($SLEEP_TIME seconds)...${NC}"
sleep $SLEEP_TIME

# Get the MongoDB ObjectId from the application
echo -e "\n${GREEN}Retrieving MongoDB ObjectId from application...${NC}"

# Get the most recently created product from the API
RECENT_PRODUCTS=$(curl -s "http://localhost:8080/api/product?page=0&size=1&sort=createdAt,desc")
PRODUCT_ID=$(echo "$RECENT_PRODUCTS" | jq -r '.content[0].id')

if [ -z "$PRODUCT_ID" ] || [ "$PRODUCT_ID" == "null" ]; then
  echo -e "${RED}Failed to find a recently created product. Trying to extract from logs...${NC}"
  
  # Alternative approach: Extract from logs
  LOGS=$(cd /home/saulo/workspace/fiap-alura/fase04/snackbar-management && docker-compose logs app | grep -i "product created" | tail -n 5)
  echo "Logs: $LOGS"
  
  # Extract the MongoDB ObjectId from the logs (looking for 24-character hex string)
  PRODUCT_ID=$(echo "$LOGS" | grep -o -E '[0-9a-f]{24}' | tail -n 1)
  
  if [ -z "$PRODUCT_ID" ]; then
    echo -e "${RED}Failed to extract MongoDB ObjectId. Exiting.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}Found product with MongoDB ObjectId: $PRODUCT_ID${NC}"

# Test UPDATE operation with the MongoDB ObjectId
echo -e "\n${GREEN}Testing UPDATE operation with MongoDB ObjectId${NC}"
UPDATE_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "UPDATE",
    "productId": "'$PRODUCT_ID'",
    "product": {
      "name": "Updated Test Burger",
      "category": "Lanche",
      "description": "An updated delicious test burger with extra cheese",
      "price": 17.99,
      "cookingTime": 10
    }
  }' \
  $API_URL)

echo "Response: $UPDATE_RESPONSE"

# Wait for the product to be updated in the database
echo -e "${YELLOW}Waiting for product update to be processed ($SLEEP_TIME seconds)...${NC}"
sleep $SLEEP_TIME

# Verify the update was successful
echo -e "\n${GREEN}Verifying product update...${NC}"
UPDATED_PRODUCT=$(curl -s "http://localhost:8080/api/product/id/$PRODUCT_ID")
UPDATED_NAME=$(echo "$UPDATED_PRODUCT" | jq -r '.name')

if [ "$UPDATED_NAME" == "Updated Test Burger" ]; then
  echo -e "${GREEN}Product successfully updated!${NC}"
else
  echo -e "${YELLOW}Product may not have been updated yet. Current name: $UPDATED_NAME${NC}"
fi

# Test DELETE operation with the MongoDB ObjectId
echo -e "\n${GREEN}Testing DELETE operation with MongoDB ObjectId${NC}"
DELETE_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "DELETE",
    "productId": "'$PRODUCT_ID'"
  }' \
  $API_URL)

echo "Response: $DELETE_RESPONSE"

# Wait for the product to be deleted in the database
echo -e "${YELLOW}Waiting for product deletion to be processed ($SLEEP_TIME seconds)...${NC}"
sleep $SLEEP_TIME

# Verify the delete was successful
echo -e "\n${GREEN}Verifying product deletion...${NC}"
DELETED_CHECK=$(curl -s "http://localhost:8080/api/product/id/$PRODUCT_ID")
DELETED_STATUS=$(echo "$DELETED_CHECK" | jq -r '.status // empty')

if [ "$DELETED_STATUS" == "404" ] || [[ "$DELETED_CHECK" == *"not found"* ]]; then
  echo -e "${GREEN}Product successfully deleted!${NC}"
else
  echo -e "${YELLOW}Product may not have been deleted yet. Response: $DELETED_CHECK${NC}"
fi

# Check SQS messages
echo -e "\n${GREEN}Checking SQS messages${NC}"

if [ "$ENV" == "localstack" ]; then
  # For LocalStack
  QUEUE_URL=$(terraform output -raw localstack_sqs_queue_url)
  echo -e "${YELLOW}Using LocalStack queue URL: $QUEUE_URL${NC}"
  
  # Use awslocal for LocalStack
  echo -e "\n${GREEN}Messages in queue:${NC}"
  aws --endpoint-url=http://localhost:4566 sqs receive-message \
    --queue-url $QUEUE_URL \
    --max-number-of-messages 10 \
    --wait-time-seconds 1 | jq
else
  # For real AWS
  QUEUE_URL=$(terraform output -raw product_events_queue_url)
  echo -e "${YELLOW}Using AWS queue URL: $QUEUE_URL${NC}"
  
  # Use regular AWS CLI for AWS
  echo -e "\n${GREEN}Messages in queue:${NC}"
  aws sqs receive-message \
    --queue-url $QUEUE_URL \
    --max-number-of-messages 10 \
    --wait-time-seconds 1 | jq
fi

echo -e "\n${GREEN}Test completed successfully!${NC}"
