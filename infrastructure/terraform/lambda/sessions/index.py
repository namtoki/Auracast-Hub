import json
import os
import boto3
from datetime import datetime, timedelta
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['SESSIONS_TABLE'])


def handler(event, context):
    """Handle session operations."""
    http_method = event.get('httpMethod', '')
    path_params = event.get('pathParameters', {}) or {}
    session_id = path_params.get('sessionId')

    try:
        if http_method == 'POST':
            body = json.loads(event.get('body', '{}'))
            return create_session(body)
        elif http_method == 'PUT':
            body = json.loads(event.get('body', '{}'))
            return update_session(session_id, body)
        elif http_method == 'DELETE':
            return delete_session(session_id)
        else:
            return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})


def create_session(body):
    """Create a new session."""
    required_fields = ['id', 'hostDeviceId']
    for field in required_fields:
        if field not in body:
            return response(400, {'error': f'{field} is required'})

    # Set TTL to 24 hours from now
    ttl = int((datetime.utcnow() + timedelta(hours=24)).timestamp())

    item = {
        'sessionId': body['id'],
        'hostDeviceId': body['hostDeviceId'],
        'name': body.get('name', 'Unnamed Session'),
        'createdAt': datetime.utcnow().isoformat(),
        'state': body.get('state', 'idle'),
        'devices': body.get('devices', []),
        'channelAssignments': body.get('channelAssignments', []),
        'audioConfig': body.get('audioConfig', {}),
        'bufferSizeMs': body.get('bufferSizeMs', 100),
        'ttl': ttl
    }

    # Convert to DynamoDB-safe types
    item = convert_to_decimal(item)

    table.put_item(Item=item)

    return response(201, {'sessionId': body['id']})


def update_session(session_id, body):
    """Update an existing session."""
    if not session_id:
        return response(400, {'error': 'sessionId is required'})

    # Get existing session
    result = table.get_item(Key={'sessionId': session_id})
    if 'Item' not in result:
        return response(404, {'error': 'Session not found'})

    # Update fields
    update_expr = 'SET '
    expr_values = {}
    expr_names = {}

    updateable_fields = ['state', 'devices', 'channelAssignments', 'audioConfig', 'bufferSizeMs', 'name']

    updates = []
    for field in updateable_fields:
        if field in body:
            safe_name = f'#{field}'
            safe_value = f':{field}'
            updates.append(f'{safe_name} = {safe_value}')
            expr_names[safe_name] = field
            expr_values[safe_value] = convert_to_decimal(body[field])

    if not updates:
        return response(400, {'error': 'No fields to update'})

    update_expr += ', '.join(updates)

    table.update_item(
        Key={'sessionId': session_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values
    )

    return response(200, {'message': 'Session updated'})


def delete_session(session_id):
    """Delete a session."""
    if not session_id:
        return response(400, {'error': 'sessionId is required'})

    table.delete_item(Key={'sessionId': session_id})

    return response(204, {})


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
        'body': json.dumps(body, default=str) if body else ''
    }
