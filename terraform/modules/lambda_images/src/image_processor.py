import boto3
import os
import logging
from urllib.parse import unquote_plus
from PIL import Image

# --- Logger Setup --- #
# Standard logger for clear and structured logs in CloudWatch.
# Best practice to set up the logger at the global scope.
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# --- AWS Clients Setup --- #
# Initialize the S3 client once to be reused across invocations (performance best practice).
s3_client = boto3.client('s3')

# --- Environment Variables --- #
# Fetch configuration from environment variables for flexibility.
# These will be set in the Lambda function's configuration via Terraform.
DESTINATION_PREFIX = os.environ.get('DESTINATION_PREFIX', 'processed/')
TARGET_WIDTH = int(os.environ.get('TARGET_WIDTH', 1024)) # Default to 1024 pixels wide

def resize_image(image_path, output_path, width):
    """
    Resizes an image to a specified width while maintaining its aspect ratio.

    :param image_path: The local path to the source image in /tmp.
    :param output_path: The local path to save the resized image in /tmp.
    :param width: The target width in pixels.
    """
    logger.info("Resizing image '%s' to width %d", image_path, width)
    with Image.open(image_path) as image:
        # Calculate height to maintain aspect ratio
        w_percent = (width / float(image.size[0]))
        h_size = int((float(image.size[1]) * float(w_percent)))

        # The thumbnail function is a safe way to resize; it maintains aspect ratio.
        image.thumbnail((width, h_size))
        image.save(output_path)
    logger.info("Successfully resized image and saved to '%s'", output_path)

def lambda_handler(event, context):
    """
    Main Lambda handler function triggered by an S3 event.

    :param event: The event dictionary provided by the S3 trigger.
    :param context: The Lambda runtime context object (contains metadata).
    """
    logger.info("Received event: %s", event)

    # An S3 event can contain multiple records (e.g., if multiple files are uploaded at once).
    for record in event['Records']:
        try:
            # --- 1. Get Source Bucket and Key --- #
            source_bucket = record['s3']['bucket']['name']
            # Object keys with special characters (like spaces) are URL-encoded.
            object_key = unquote_plus(record['s3']['object']['key'])

            # --- CRITICAL CHECK: Prevent Infinite Loops --- #
            # If the trigger is misconfigured and fires on our output folder, ignore the event.
            if object_key.startswith(DESTINATION_PREFIX):
                logger.warning("File '%s' is already in the destination prefix. Skipping to prevent infinite loop.", object_key)
                continue

            logger.info("Processing file 's3://%s/%s'", source_bucket, object_key)

            # --- 2. Download from S3 to /tmp --- #
            # Lambda provides a writable /tmp directory with 512MB of space by default (we configured more).
            file_name = os.path.basename(object_key)
            download_path = os.path.join('/tmp', file_name)
            upload_path = os.path.join('/tmp', f"resized-{file_name}")

            logger.info("Downloading file to '%s'", download_path)
            s3_client.download_file(source_bucket, object_key, download_path)

            # --- 3. Process the Image --- #
            resize_image(download_path, upload_path, TARGET_WIDTH)

            # --- 4. Upload Result to Destination Prefix in the Same Bucket --- #
            # Example: from 'uploads/image.jpg' to 'processed/image.jpg'
            destination_key = os.path.join(DESTINATION_PREFIX, file_name)

            logger.info("Uploading '%s' to 's3://%s/%s'", upload_path, source_bucket, destination_key)
            s3_client.upload_file(upload_path, source_bucket, destination_key)

            logger.info("Successfully processed and uploaded to 's3://%s/%s'", source_bucket, destination_key)

        except Exception as e:
            logger.error("Error processing file '%s' from bucket '%s'. Error: %s", object_key, source_bucket, e, exc_info=True)
            # Re-raise the exception to mark this invocation as failed. This is crucial for
            # triggering AWS Lambda's retry mechanism and eventually sending the event to the DLQ.
            raise e

    return {
        'statusCode': 200,
        'body': 'Image processing completed successfully!'
    }
