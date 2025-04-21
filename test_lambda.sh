#!/bin/bash
# Script to test the product operations Lambda function with sleep timers
# to allow the application to process each message before proceeding to the next operation

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
  API_URL="http://localhost:4566/restapis/$(terraform output -raw product_operations_api_id)/test/_user_request_/product-operations"
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

# Extract product ID from response
PRODUCT_ID=$(echo $CREATE_RESPONSE | jq -r '.data.productId // empty')

if [ -z "$PRODUCT_ID" ]; then
  echo -e "${RED}Failed to extract product ID from response${NC}"
  exit 1
fi

echo -e "${GREEN}Created product with ID: $PRODUCT_ID${NC}"

# Wait for the product to be created in the database
echo -e "${YELLOW}Waiting for product creation to be processed ($SLEEP_TIME seconds)...${NC}"
sleep $SLEEP_TIME

# Test UPDATE operation
echo -e "\n${GREEN}Testing UPDATE operation${NC}"
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

# Test DELETE operation
echo -e "\n${GREEN}Testing DELETE operation${NC}"
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
