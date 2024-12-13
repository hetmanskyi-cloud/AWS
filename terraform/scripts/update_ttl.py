# --- AWS Lambda Function for TTL Automation --- #
# This Python script processes DynamoDB Streams and updates the `ExpirationTime` attribute
# for new or modified items to ensure proper TTL functionality. It includes logging for
# both local debugging and CloudWatch Logs, and it ensures idempotent updates to avoid
# redundant operations.

import boto3
import time
import os
import logging

# --- Logging Configuration --- #
# Check environment to determine logging destination.
is_local = os.getenv("AWS_EXECUTION_ENV") is None

# Configure logging for local and CloudWatch environments
if is_local:
    logging.basicConfig(filename="lambda_debug.log", level=logging.INFO)
else:
    logging.basicConfig(level=logging.INFO)

logger = logging.getLogger(__name__)

# Initialize DynamoDB client
dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    """
    Lambda handler function that processes DynamoDB Streams and updates the `ExpirationTime`.

    Args:
        event: The event data from DynamoDB Streams.
        context: The runtime context of the Lambda function.

    Returns:
        dict: The status of the processing.
    """
    processed_records = 0
    failed_records = 0

    for record in event['Records']:
        if record['eventName'] in ['INSERT', 'MODIFY']:
            try:
                # Extract table name and primary key from the record
                table_name = record['eventSourceARN'].split("/")[1]
                lock_id = record['dynamodb']['Keys']['LockID']['S']

                # Get current ExpirationTime
                response = dynamodb.get_item(
                    TableName=table_name,
                    Key={'LockID': {'S': lock_id}},
                    AttributesToGet=['ExpirationTime']
                )
                current_expiration = int(response['Item']['ExpirationTime']['N']) if 'Item' in response else 0
                new_expiration_time = int(time.time()) + 3600

                # Skip update if current ExpirationTime is up-to-date
                if current_expiration >= new_expiration_time:
                    logger.info(f"Skipping update for LockID {lock_id}: ExpirationTime is already up-to-date.")
                    continue

                # Update the item in the DynamoDB table
                dynamodb.update_item(
                    TableName=table_name,
                    Key={'LockID': {'S': lock_id}},
                    UpdateExpression="SET ExpirationTime = :et",
                    ExpressionAttributeValues={":et": {"N": str(new_expiration_time)}}
                )

                processed_records += 1

            except Exception as e:
                logger.error(f"Error processing record {record}: {e}")
                failed_records += 1

    # Log the processing summary
    logger.info(f"Processed {processed_records} records successfully.")
    logger.info(f"Failed to process {failed_records} records.")

    return {
        'statusCode': 200 if failed_records == 0 else 207,  # 207: Multi-Status (indicates partial success)
        'body': f"Successfully processed {processed_records} records. Errors encountered: {failed_records}."
    }

# --- Notes --- #
# 1. The script updates the `ExpirationTime` attribute for each new or modified record in the DynamoDB table.
# 2. The `ExpirationTime` is set to 1 hour (3600 seconds) from the current time.
# 3. Idempotent updates ensure records are only updated if needed, avoiding redundant writes.
# 4. Logging is configured for both local debugging (file-based) and CloudWatch Logs.
# 5. The script should be deployed as a zip archive in the `scripts` folder (e.g., `update_ttl.zip`).