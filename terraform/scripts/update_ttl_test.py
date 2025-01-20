# --- AWS Lambda Function for TTL Automation (Test Version) --- #
# This script is designed for local testing of the TTL automation logic.
# It uses mock data instead of real DynamoDB Streams to simulate Lambda functionality.

import boto3
import time
import logging

# --- Logging Configuration --- #
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Mock DynamoDB Client --- #
# Replace this with a mock or stub for local testing if needed.
dynamodb = boto3.client('dynamodb', region_name='us-east-1')

def lambda_handler(event, context):
    """
    Lambda handler function for processing DynamoDB Streams and updating `ExpirationTime`.

    Args:
        event: The event data from DynamoDB Streams (mocked for testing).
        context: The runtime context of the Lambda function (not used in testing).

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

                # Simulate fetching current ExpirationTime
                current_expiration = 0  # Default value for testing
                new_expiration_time = int(time.time()) + 3600

                # Log the mock processing
                logger.info(f"Updating LockID {lock_id} in table {table_name} with new expiration time {new_expiration_time}.")

                processed_records += 1

            except Exception as e:
                logger.error(f"Error processing record {record}: {e}")
                failed_records += 1

    # Log the processing summary
    logger.info(f"Processed {processed_records} records successfully.")
    logger.info(f"Failed to process {failed_records} records.")

    return {
        'statusCode': 200 if failed_records == 0 else 207,
        'body': f"Successfully processed {processed_records} records. Errors encountered: {failed_records}."
    }

# --- Main Block for Local Testing --- #
if __name__ == "__main__":
    # Mock event data simulating DynamoDB Streams
    mock_event = {
        "Records": [
            {
                "eventName": "INSERT",
                "eventSourceARN": "arn:aws:dynamodb:us-east-1:123456789012:table/TestTable",
                "dynamodb": {
                    "Keys": {"LockID": {"S": "test-lock-id"}},
                    "NewImage": {"ExpirationTime": {"N": "0"}}
                }
            },
            {
                "eventName": "MODIFY",
                "eventSourceARN": "arn:aws:dynamodb:us-east-1:123456789012:table/TestTable",
                "dynamodb": {
                    "Keys": {"LockID": {"S": "modify-lock-id"}},
                    "NewImage": {"ExpirationTime": {"N": "0"}}
                }
            }
        ]
    }

    # Call the handler function with mock data
    response = lambda_handler(mock_event, None)

    # Output the response
    logger.info(f"Lambda Handler Response: {response}")
