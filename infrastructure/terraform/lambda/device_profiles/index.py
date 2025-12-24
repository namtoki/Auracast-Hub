import json
import os
import boto3
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DEVICE_PROFILES_TABLE'])


def handler(event, context):
    """Handle device profile operations."""
    http_method = event.get('httpMethod', '')
    resource = event.get('resource', '')

    try:
        if http_method == 'POST':
            body = json.loads(event.get('body', '{}'))
            return post_device_profile(body)
        elif http_method == 'GET' and 'recommended' in resource:
            params = event.get('queryStringParameters', {}) or {}
            return get_recommended(params)
        else:
            return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})


def post_device_profile(body):
    """Submit a device profile."""
    required_fields = ['deviceId', 'model', 'platform', 'osVersion']
    for field in required_fields:
        if field not in body:
            return response(400, {'error': f'{field} is required'})

    body['createdAt'] = datetime.utcnow().isoformat()

    # Convert floats to Decimal for DynamoDB
    body = convert_to_decimal(body)

    table.put_item(Item=body)

    return response(201, {'message': 'Device profile submitted'})


def get_recommended(params):
    """Get recommended buffer size for a device model."""
    model = params.get('model')
    platform = params.get('platform')

    if not model or not platform:
        return response(400, {'error': 'model and platform are required'})

    # Query by model using GSI
    result = table.query(
        IndexName='model-index',
        KeyConditionExpression='model = :model',
        ExpressionAttributeValues={':model': model},
        Limit=100
    )

    items = result.get('Items', [])

    if not items:
        # Return default recommendation
        return response(200, {
            'model': model,
            'platform': platform,
            'recommendedBufferMs': 100,
            'sampleCount': 0
        })

    # Calculate average recommended buffer
    buffer_values = [
        int(item.get('recommendedBufferMs', 100))
        for item in items
        if item.get('platform') == platform
    ]

    if not buffer_values:
        buffer_values = [100]

    avg_buffer = sum(buffer_values) // len(buffer_values)

    return response(200, {
        'model': model,
        'platform': platform,
        'recommendedBufferMs': avg_buffer,
        'sampleCount': len(buffer_values)
    })


def convert_to_decimal(obj):
    """Convert floats to Decimal for DynamoDB."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    elif isinstance(obj, dict):
        return {k: convert_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_to_decimal(i) for i in obj]
    return obj


def response(status_code, body):
    """Create API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }
