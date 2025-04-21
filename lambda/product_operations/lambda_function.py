import json
import uuid
import time
import os
import boto3
import logging
import re
from typing import Dict, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
sqs_client = boto3.client('sqs',
                         region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Get the SQS queue URL from environment variable
QUEUE_URL = os.environ.get('SQS_QUEUE_URL')

# Event types
EVENT_TYPE_CREATED = "PRODUCT_CREATED"
EVENT_TYPE_UPDATED = "PRODUCT_UPDATED"
EVENT_TYPE_DELETED = "PRODUCT_DELETED"

# MongoDB ObjectId pattern (24 hex characters)
OBJECT_ID_PATTERN = re.compile(r'^[0-9a-f]{24}$')

def is_valid_object_id(id_str: str) -> bool:
    """
    Check if a string is a valid MongoDB ObjectId.
    
    Args:
        id_str: The ID string to check
        
    Returns:
        True if the string is a valid MongoDB ObjectId, False otherwise
    """
    if not id_str:
        return False
    return bool(OBJECT_ID_PATTERN.match(id_str))

def validate_product(product: Dict[str, Any]) -> None:
    """
    Validates product data according to business rules.
    
    Args:
        product: Dictionary containing product data
        
    Raises:
        ValueError: If product data is invalid
    """
    required_fields = ['name', 'category', 'description', 'price', 'cookingTime']
    
    # Check required fields
    for field in required_fields:
        if field not in product:
            raise ValueError(f"Missing required field: {field}")
    
    # Validate name
    if len(product['name']) < 3:
        raise ValueError("Product name must be at least 3 characters long")
    
    # Validate category
    valid_categories = ["Lanche", "Acompanhamento", "Bebida", "Sobremesa"]
    if product['category'] not in valid_categories:
        raise ValueError(f"Invalid category. Must be one of: {', '.join(valid_categories)}")
    
    # Validate description
    if len(product['description']) < 10:
        raise ValueError("Product description must be at least 10 characters long")
    
    # Validate price
    if not isinstance(product['price'], (int, float)) or product['price'] <= 0:
        raise ValueError("Product price must be greater than 0")
    
    # Validate cookingTime
    if not isinstance(product['cookingTime'], (int, float)) or product['cookingTime'] < 0:
        raise ValueError("Product cookingTime must be greater than or equal to 0")

def create_product_message(product_id: str, product_data: Dict[str, Any], event_type: str) -> Dict[str, Any]:
    """
    Creates a product message in the format expected by the consumer.
    
    Args:
        product_id: The ID of the product
        product_data: Dictionary containing product data
        event_type: Type of event (PRODUCT_CREATED, PRODUCT_UPDATED, PRODUCT_DELETED)
        
    Returns:
        Dictionary containing the formatted message
    """
    message = {
        "messageId": str(uuid.uuid4()),
        "eventType": event_type,
        "timestamp": time.time(),
        "productId": product_id
    }
    
    # For delete events, we only need the product ID
    if event_type != EVENT_TYPE_DELETED:
        message.update({
            "name": product_data.get('name'),
            "category": product_data.get('category'),
            "description": product_data.get('description'),
            "price": product_data.get('price'),
            "cookingTime": product_data.get('cookingTime')
        })
    
    return message

def send_to_sqs(message: Dict[str, Any]) -> Dict[str, Any]:
    """
    Sends a message to the SQS queue.
    
    Args:
        message: Dictionary containing the message to send
        
    Returns:
        SQS response
    """
    if not QUEUE_URL:
        raise ValueError("SQS_QUEUE_URL environment variable is not set")
    
    logger.info(f"Sending message to SQS queue: {QUEUE_URL}")
    logger.debug(f"Message content: {json.dumps(message)}")
    
    response = sqs_client.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message)
    )
    
    logger.info(f"Message sent successfully. MessageId: {response.get('MessageId')}")
    return response

def handle_create_product(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handles a create product operation.
    
    Args:
        event: Lambda event containing product data
        
    Returns:
        Response dictionary
    """
    try:
        product_data = event.get('product', {})
        validate_product(product_data)
        
        # For CREATE operations, we don't send a product ID
        # This allows the consumer to generate a MongoDB ObjectId
        
        # Create the message with null productId
        message = create_product_message(None, product_data, EVENT_TYPE_CREATED)
        
        # Send to SQS
        sqs_response = send_to_sqs(message)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'message': 'Product creation request sent successfully',
                'data': {
                    'sqsMessageId': sqs_response.get('MessageId')
                }
            })
        }
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'success': False,
                'message': str(e)
            })
        }
    except Exception as e:
        logger.error(f"Error creating product: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f"Internal server error: {str(e)}"
            })
        }

def handle_update_product(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handles an update product operation.
    
    Args:
        event: Lambda event containing product data
        
    Returns:
        Response dictionary
    """
    try:
        product_data = event.get('product', {})
        product_id = event.get('productId')
        
        if not product_id:
            raise ValueError("Product ID is required for update operations")
        
        # Validate that the product ID is a valid MongoDB ObjectId
        if not is_valid_object_id(product_id):
            raise ValueError("Invalid product ID format. Must be a valid MongoDB ObjectId (24 hex characters)")
        
        validate_product(product_data)
        
        # Create the message with the MongoDB ObjectId
        message = create_product_message(product_id, product_data, EVENT_TYPE_UPDATED)
        
        # Send to SQS
        sqs_response = send_to_sqs(message)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'message': 'Product update request sent successfully',
                'data': {
                    'productId': product_id,
                    'sqsMessageId': sqs_response.get('MessageId')
                }
            })
        }
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'success': False,
                'message': str(e)
            })
        }
    except Exception as e:
        logger.error(f"Error updating product: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f"Internal server error: {str(e)}"
            })
        }

def handle_delete_product(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handles a delete product operation.
    
    Args:
        event: Lambda event containing product ID
        
    Returns:
        Response dictionary
    """
    try:
        product_id = event.get('productId')
        
        if not product_id:
            raise ValueError("Product ID is required for delete operations")
        
        # Validate that the product ID is a valid MongoDB ObjectId
        if not is_valid_object_id(product_id):
            raise ValueError("Invalid product ID format. Must be a valid MongoDB ObjectId (24 hex characters)")
        
        # Create the message with the MongoDB ObjectId
        message = create_product_message(product_id, {}, EVENT_TYPE_DELETED)
        
        # Send to SQS
        sqs_response = send_to_sqs(message)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'message': 'Product deletion request sent successfully',
                'data': {
                    'productId': product_id,
                    'sqsMessageId': sqs_response.get('MessageId')
                }
            })
        }
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'success': False,
                'message': str(e)
            })
        }
    except Exception as e:
        logger.error(f"Error deleting product: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f"Internal server error: {str(e)}"
            })
        }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function.
    
    Args:
        event: Lambda event
        context: Lambda context
        
    Returns:
        Response dictionary
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Check if the event is from API Gateway v2 (HTTP API)
    if 'body' in event and isinstance(event['body'], str):
        try:
            # Parse the JSON body
            body = json.loads(event['body'])
            # Use the body as the event for further processing
            operation = body.get('operation', '').upper()
            # Pass the body as the event to the handler functions
            if operation == 'CREATE':
                return handle_create_product(body)
            elif operation == 'UPDATE':
                return handle_update_product(body)
            elif operation == 'DELETE':
                return handle_delete_product(body)
            else:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'message': f"Unsupported operation: {operation}. Must be one of: CREATE, UPDATE, DELETE"
                    })
                }
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing request body: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'message': f"Invalid JSON in request body: {str(e)}"
                })
            }
    else:
        # Direct invocation (not through API Gateway)
        operation = event.get('operation', '').upper()
        
        if operation == 'CREATE':
            return handle_create_product(event)
        elif operation == 'UPDATE':
            return handle_update_product(event)
        elif operation == 'DELETE':
            return handle_delete_product(event)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'message': f"Unsupported operation: {operation}. Must be one of: CREATE, UPDATE, DELETE"
                })
            }
