import boto3
import os
import logging
from botocore.config import Config
from botocore.exceptions import ClientError

# Initialize logger
logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))

# Add retry configuration
config = Config(
    retries={
        'max_attempts': 5,  # Maximum retry attempts
        'mode': 'standard'  # Retry mode: standard/exponential
    }
)

# Initialize AWS clients
rds_client = boto3.client("rds", config=config)
sns_client = boto3.client("sns")
dynamodb_client = boto3.client("dynamodb")

def send_sns_notification(message: str, subject: str):
    """
    Send a notification to an SNS topic.
    Args:
        message (str): The message to send.
        subject (str): The subject of the notification.
    """
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

def update_replica_status_in_dynamodb(read_replica_identifier: str, status: str):
    """
    Update the status of a replica in DynamoDB.
    Args:
        read_replica_identifier (str): The identifier of the replica.
        status (str): The status of the replica (e.g., "deleted").
    """
    try:
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

def lambda_handler(event, context):
    """
    AWS Lambda function to delete an RDS read replica.

    Args:
        event (dict): Event data containing input parameters.
        context (object): AWS Lambda context object.

    Returns:
        dict: Status and details of the operation.
    """
    # Get parameters from environment variables or event data
    read_replica_identifier = os.getenv("READ_REPLICA_IDENTIFIER", event.get("read_replica_identifier"))
    if not read_replica_identifier:
        logger.error("READ_REPLICA_IDENTIFIER environment variable is not provided. Exiting.")
        raise ValueError("READ_REPLICA_IDENTIFIER is a required parameter.")

    # Check if the replica exists
    try:
        logger.info(f"Checking existence of read replica: {read_replica_identifier}")
        rds_client.describe_db_instances(DBInstanceIdentifier=read_replica_identifier)
    except rds_client.exceptions.DBInstanceNotFoundFault:
        logger.info(f"No read replica found with ID {read_replica_identifier}. Nothing to delete.")
        return {"status": "success", "message": f"No read replica found with ID {read_replica_identifier}."}
    except ClientError as e:
        error_message = f"Error checking replica existence: {e.response['Error']['Message']}"
        logger.error(error_message)
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Deletion Error"
        )
        return {"status": "error", "details": error_message}

    # If replica exists, proceed to delete
    try:
        logger.info(f"Deleting read replica: {read_replica_identifier}")
        response = rds_client.delete_db_instance(
            DBInstanceIdentifier=read_replica_identifier,
            SkipFinalSnapshot=True  # Skip creating a final snapshot
        )
        logger.info(f"Read replica {read_replica_identifier} successfully deleted. It is no longer accessible.")
        update_replica_status_in_dynamodb(read_replica_identifier, "deleted")
        send_sns_notification(
            message=f"Read replica {read_replica_identifier} successfully deleted.",
            subject="RDS Replica Deletion Success"
        )
        return {"status": "success", "details": response}
    except ClientError as e:
        error_message = f"Error deleting read replica: {e.response['Error']['Message']}"
        logger.error(error_message)
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Deletion Error"
        )
        return {"status": "error", "details": error_message}
    except Exception as e:
        error_message = f"Unexpected error during replica deletion: {str(e)}"
        logger.error(error_message)
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Deletion Unexpected Error"
        )
        return {"status": "error", "details": error_message}
