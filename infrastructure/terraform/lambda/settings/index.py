import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['USER_SETTINGS_TABLE'])


def handler(event, context):
    """Handle settings CRUD operations."""
    http_method = event.get('httpMethod', '')
    path_params = event.get('pathParameters', {}) or {}
    user_id = path_params.get('userId')

    try:
        if http_method == 'GET':
            return get_settings(user_id)
        elif http_method == 'PUT':
            body = json.loads(event.get('body', '{}'))
            return put_settings(user_id, body)
        else:
            return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})


def get_settings(user_id):
    """Get user settings."""
    if not user_id:
        return response(400, {'error': 'userId is required'})

    result = table.get_item(Key={'userId': user_id})
    item = result.get('Item')

    if not item:
        return response(404, {'error': 'Settings not found'})

    return response(200, item)


def put_settings(user_id, body):
    """Create or update user settings."""
    if not user_id:
        return response(400, {'error': 'userId is required'})

    body['userId'] = user_id
    body['lastUpdated'] = datetime.utcnow().isoformat()

    table.put_item(Item=body)

    return response(200, body)


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
