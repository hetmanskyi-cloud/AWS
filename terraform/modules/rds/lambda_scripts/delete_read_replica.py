import boto3
import os

def lambda_handler(event, context):
    # Get parameters from environment variables or event data
    read_replica_identifier = os.getenv("READ_REPLICA_IDENTIFIER", event.get("read_replica_identifier"))

    # Initialize RDS client
    rds_client = boto3.client("rds")

    try:
        # Delete the specified read replica
        response = rds_client.delete_db_instance(
            DBInstanceIdentifier=read_replica_identifier,
            SkipFinalSnapshot=True  # Skip creating a final snapshot
        )
        print(f"Read replica {read_replica_identifier} successfully deleted.")
        return {"status": "success", "details": response}
    except Exception as e:
        # Log and return error details if deletion fails
        print(f"Error deleting read replica: {e}")
        return {"status": "error", "details": str(e)}
