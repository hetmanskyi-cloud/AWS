# AWS Lambda function for processing images from an S3 bucket.
#
# This function is triggered by messages from an SQS queue. The SQS message body
# is expected to contain an S3 event notification for an object creation.
#
# The function performs the following steps:
# 1. Parses the S3 event from the SQS message.
# 2. Downloads the source image from the source S3 prefix.
# 3. Resizes the image to a configurable width.
# 4. Uploads the processed image to a destination S3 prefix.
# 5. Writes metadata about the operation to a DynamoDB table.

import boto3
import os
import logging
import json
import time
from urllib.parse import unquote_plus
from PIL import Image

# --- Logger Setup --- #
# A standard logger for clear and structured logs which will appear in CloudWatch.
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# --- AWS Clients Setup --- #
# Initialize clients once at the global scope to be reused across warm invocations.
# This is a performance best practice for Lambda functions.
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# --- Environment Variables --- #
# Fetch configuration from environment variables for flexibility.
# These are set in the Lambda function's configuration via Terraform.
DESTINATION_PREFIX = os.environ.get('DESTINATION_PREFIX')
TARGET_WIDTH = int(os.environ['TARGET_WIDTH'])
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

# --- Startup Sanity Check --- #
# Perform a "fail-fast" check during the cold start to ensure all required
# environment variables are configured. This prevents the function from running
# with an invalid configuration on every invocation.
missing_env_vars = []
if not TABLE_NAME:
    missing_env_vars.append('DYNAMODB_TABLE_NAME')
if not DESTINATION_PREFIX:
    missing_env_vars.append('DESTINATION_PREFIX')

if missing_env_vars:
    error_msg = f"Missing environment variables: {', '.join(missing_env_vars)}"
    logger.error("FATAL: %s", error_msg)
    raise ValueError(error_msg)

def resize_image(image_path, output_path, width):
    """
    Resizes an image to a specified width while maintaining its aspect ratio.
    """
    logger.info("Resizing image '%s' to width %d", image_path, width)
    with Image.open(image_path) as image:
        # The thumbnail method safely resizes the image to fit within a
        # (width, width) box while maintaining the aspect ratio.
        image.thumbnail((width, width))
        image.save(output_path)
    logger.info("Successfully resized image and saved to '%s'", output_path)

def lambda_handler(event, context):
    """
    Main Lambda handler triggered by SQS.
    """
    logger.info("Received SQS event with %d message(s).", len(event.get('Records', [])))

    table = dynamodb.Table(TABLE_NAME)

    for sqs_record in event['Records']:
        try:
            # 1. Parse SQS Message and S3 Event
            # The actual S3 event notification is a JSON string inside the SQS message body.
            s3_event_body = json.loads(sqs_record['body'])
            logger.info("Parsed S3 event from SQS message.")

            for s3_record in s3_event_body['Records']:
                source_bucket = s3_record['s3']['bucket']['name']
                # Object keys can contain URL-encoded characters (e.g., '+' for spaces).
                object_key = unquote_plus(s3_record['s3']['object']['key'])

                # CRITICAL: This check prevents infinite loops if the S3 trigger is
                # ever misconfigured to also fire on the destination prefix.
                if object_key.startswith(DESTINATION_PREFIX):
                    logger.warning("File '%s' is already in the destination prefix. Skipping.", object_key)
                    continue

                logger.info("Processing file: s3://%s/%s", source_bucket, object_key)

                # 2. Download Source Image to Temporary Storage
                # Lambda provides a writable /tmp directory for temporary files.
                file_name = os.path.basename(object_key)
                download_path = os.path.join('/tmp', file_name)
                upload_path = os.path.join('/tmp', f"resized-{file_name}")

                logger.info("Downloading file to '%s'", download_path)
                s3_client.download_file(source_bucket, object_key, download_path)

                # 3. Process Image
                resize_image(download_path, upload_path, TARGET_WIDTH)

                # 4. Upload Processed Image
                # This constructs a robust destination path, ensuring no double slashes.
                destination_key = f"{DESTINATION_PREFIX.rstrip('/')}/{file_name}"
                s3_client.upload_file(upload_path, source_bucket, destination_key)
                logger.info("Uploaded processed file to 's3://%s/%s'", source_bucket, destination_key)

                # 5. Write Metadata to DynamoDB
                logger.info("Writing metadata to DynamoDB table: %s", TABLE_NAME)
                processed_size = os.path.getsize(upload_path)

                item_to_save = {
                    'ImageID': file_name,  # Partition Key
                    'Status': 'processed',
                    'SourceKey': object_key,
                    'ProcessedKey': destination_key,
                    'ProcessedSize': processed_size,
                    'TargetWidth': TARGET_WIDTH,
                    'ProcessingTimestamp': int(time.time())
                }

                table.put_item(Item=item_to_save)
                logger.info("Metadata saved to DynamoDB for '%s'.", file_name)

        except Exception as e:
            # This generic exception handler catches any error during the process.
            logger.error("Error processing SQS message. Message body: %s", sqs_record.get('body'), exc_info=True)
            # Re-raising the exception is crucial. It signals to the Lambda service that the
            # invocation failed, preventing the message from being deleted from the SQS queue.
            # This allows SQS to handle retries and eventually send the message to the DLQ.
            raise e

    return {
        'statusCode': 200,
        'body': 'Processing completed.'
    }

# --- Notes --- #
# 1. Architecture: This function is a consumer in an event-driven architecture.
#    It is triggered by an SQS queue that receives notifications from an S3 bucket.
#    After processing, it writes the result to S3 and metadata to DynamoDB.
#
# 2. Configuration: The script is configured entirely via environment variables
#    (DYNAMODB_TABLE_NAME, DESTINATION_PREFIX, TARGET_WIDTH), which are set by Terraform.
#    This decouples the code from the infrastructure.
#
# 3. Error Handling: The function is designed to be fault-tolerant. Any exception
#    during the processing of a message will cause the function to fail. This failure
#    is reported back to the SQS trigger, which will re-drive the message according
#    to its redrive policy, eventually sending it to the configured Dead Letter Queue (DLQ).
#
# 4. Dependencies: This script requires the 'Pillow' library for image manipulation.
#    This dependency is not included in the standard Lambda runtime and MUST be provided
#    via a Lambda Layer, which is built and attached by our Terraform modules.
