import boto3
import os
import logging
from botocore.config import Config
from botocore.exceptions import ClientError

# Initialize logger
logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))

# Add retry configuration for AWS clients
config = Config(
    retries={
        'max_attempts': 5,
        'mode': 'standard'
    }
)

# Initialize AWS clients
rds_client = boto3.client("rds", config=config)
sns_client = boto3.client("sns", config=config)
dynamodb_client = boto3.client("dynamodb", config=config)

# Helper function to send SNS notifications
def send_sns_notification(message: str, subject: str):
    sns_topic_arn = os.getenv("SNS_TOPIC_ARN")
    if not sns_topic_arn:
        logger.error("SNS_TOPIC_ARN environment variable is not set.")
        return
    try:
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=message,
            Subject=subject
        )
        logger.info(f"SNS notification sent: {subject}")
    except Exception as e:
        logger.error(f"Failed to send SNS notification: {e}")

# Helper function to update replica status in DynamoDB
def update_replica_status_in_dynamodb(read_replica_identifier: str, status: str):
    try:
        logger.info(f"Updating DynamoDB: {read_replica_identifier} status -> {status}")
        dynamodb_client.update_item(
            TableName=os.getenv("DYNAMODB_TABLE_NAME"),
            Key={"db_instance_identifier": {"S": read_replica_identifier}},
            UpdateExpression="SET #status = :status",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={":status": {"S": status}}
        )
        logger.info(f"Replica {read_replica_identifier} status updated to {status} in DynamoDB.")
    except Exception as e:
        logger.error(f"Error updating DynamoDB: {e}")

# Lambda handler entry point
def lambda_handler(event, context):
    logger.info("Starting Lambda function for deleting a read replica.")
    
    # Checking mandatory environment variables
    dynamodb_table_name = os.getenv("DYNAMODB_TABLE_NAME")
    read_replica_identifier = os.getenv("READ_REPLICA_IDENTIFIER", event.get("read_replica_identifier"))

    if not dynamodb_table_name:
        logger.error("DYNAMODB_TABLE_NAME is not provided. Exiting.")
        raise ValueError("DYNAMODB_TABLE_NAME is a required parameter.")

    if not read_replica_identifier:
        logger.error("READ_REPLICA_IDENTIFIER is not provided. Exiting.")
        raise ValueError("READ_REPLICA_IDENTIFIER is a required parameter.")

    # Checking for replica availability
    try:
        rds_client.describe_db_instances(DBInstanceIdentifier=read_replica_identifier)
    except rds_client.exceptions.DBInstanceNotFoundFault:
        logger.info(f"No read replica found with ID {read_replica_identifier}.")
        return {"status": "success", "message": f"No replica found for ID {read_replica_identifier}."}

    # Deleting a replica
    try:
        response = rds_client.delete_db_instance(
            DBInstanceIdentifier=read_replica_identifier,
            SkipFinalSnapshot=True
        )
        update_replica_status_in_dynamodb(read_replica_identifier, "deleted")
        send_sns_notification(
            message=f"Read replica {read_replica_identifier} successfully deleted.",
            subject="RDS Replica Deletion Success"
        )
        return {"status": "success", "details": response}
    except ClientError as e:
        error_message = f"Error deleting read replica: {e.response['Error']['Message']}"
        logger.error(error_message)
        update_replica_status_in_dynamodb(read_replica_identifier, "error")
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Deletion Error"
        )
        return {"status": "error", "details": error_message}
