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
def track_replica_status(db_instance_identifier: str, replica_index: int, status: str):
    try:
        logger.info(f"Updating DynamoDB: {db_instance_identifier}-{replica_index} status -> {status}")
        dynamodb_client.put_item(
            TableName=os.getenv("DYNAMODB_TABLE_NAME"),
            Item={
                "db_instance_identifier": {"S": db_instance_identifier},
                "replica_index": {"N": str(replica_index)},
                "status": {"S": status}
            }
        )
        logger.info(f"Replica {replica_index} for {db_instance_identifier} status updated to {status}.")
    except Exception as e:
        logger.error(f"Error updating DynamoDB: {e}")

# Main function to create a read replica
def create_read_replica(db_instance_identifier: str, replica_index: int, environment: str, name_prefix: str):
    read_replica_identifier = f"{name_prefix}-replica-{replica_index}-{environment}"
    try:
        logger.info(f"Creating read replica with identifier: {read_replica_identifier}")
        track_replica_status(db_instance_identifier, replica_index, "creating")
        response = rds_client.create_db_instance_read_replica(
            DBInstanceIdentifier=read_replica_identifier,
            SourceDBInstanceIdentifier=db_instance_identifier
        )
        logger.info(f"Read replica {read_replica_identifier} successfully created.")
        track_replica_status(db_instance_identifier, replica_index, "available")
        send_sns_notification(
            message=f"Read replica {read_replica_identifier} successfully created.",
            subject="RDS Replica Creation Success"
        )
        return {"status": "success", "details": response.get("DBInstance", {})}
    except ClientError as e:
        error_message = f"Error creating read replica: {e.response['Error']['Message']}"
        logger.error(error_message)
        track_replica_status(db_instance_identifier, replica_index, "error")
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Creation Error"
        )
        return {"status": "error", "details": error_message}
    except Exception as e:
        error_message = f"Unexpected error during replica creation: {str(e)}"
        logger.error(error_message)
        track_replica_status(db_instance_identifier, replica_index, "error")
        send_sns_notification(
            message=error_message,
            subject="RDS Replica Creation Unexpected Error"
        )
        return {"status": "error", "details": error_message}

# Lambda handler entry point
def lambda_handler(event: dict, context: object) -> dict:
    logger.info("Starting Lambda function for creating a read replica.")

    # Fetching environment variables
    db_instance_identifier = os.getenv("DB_INSTANCE_IDENTIFIER")
    replica_index = int(os.getenv("REPLICA_INDEX", 1))
    environment = os.getenv("ENVIRONMENT", "dev")
    name_prefix = os.getenv("NAME_PREFIX", "mydb")

    if not db_instance_identifier:
        logger.error("DB_INSTANCE_IDENTIFIER is not provided. Exiting.")
        raise ValueError("DB_INSTANCE_IDENTIFIER is a required parameter.")

    # Logging parameters
    logger.info(f"DB_INSTANCE_IDENTIFIER={db_instance_identifier}, REPLICA_INDEX={replica_index}")

    # Creating a replica
    return create_read_replica(db_instance_identifier, replica_index, environment, name_prefix)
