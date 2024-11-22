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
        'max_attempts': 5,
        'mode': 'standard'
    }
)

# Initialize AWS clients
rds_client = boto3.client("rds", config=config)
sns_client = boto3.client("sns")
dynamodb_client = boto3.client("dynamodb")

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

def track_replica_status(db_instance_identifier: str, replica_index: int, status: str):
    try:
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

def get_next_replica_index(db_instance_identifier: str) -> int:
    try:
        response = dynamodb_client.query(
            TableName=os.getenv("DYNAMODB_TABLE_NAME"),
            KeyConditionExpression="db_instance_identifier = :db_id",
            ExpressionAttributeValues={":db_id": {"S": db_instance_identifier}}
        )
        items = response.get("Items", [])
        if not items:
            return 1
        existing_indices = [int(item["replica_index"]["N"]) for item in items]
        return max(existing_indices) + 1
    except Exception as e:
        logger.error(f"Error querying DynamoDB: {e}")
        return 1

def create_read_replica(db_instance_identifier: str, replica_index: int, environment: str, name_prefix: str):
    read_replica_identifier = f"{name_prefix}-replica-{replica_index}-{environment}"
    try:
        logger.info(f"Creating read replica: {read_replica_identifier}")
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

def lambda_handler(event: dict, context: object) -> dict:
    db_instance_identifier = os.getenv("DB_INSTANCE_IDENTIFIER")
    environment = os.getenv("ENVIRONMENT", "dev")
    name_prefix = os.getenv("NAME_PREFIX", "mydb")

    if not db_instance_identifier:
        logger.error("DB_INSTANCE_IDENTIFIER is not provided. Exiting.")
        raise ValueError("DB_INSTANCE_IDENTIFIER is a required parameter.")

    next_replica_index = get_next_replica_index(db_instance_identifier)
    return create_read_replica(db_instance_identifier, next_replica_index, environment, name_prefix)