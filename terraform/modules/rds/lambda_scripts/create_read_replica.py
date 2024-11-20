import boto3
import os

def lambda_handler(event, context):
    # Get parameters from environment variables or event data
    db_instance_identifier = os.getenv("DB_INSTANCE_IDENTIFIER", event.get("db_instance_identifier"))
    read_replica_identifier = f"{db_instance_identifier}-replica"

    # Initialize RDS client
    rds_client = boto3.client("rds")

    try:
        # Create a read replica for the specified database instance
        response = rds_client.create_db_instance_read_replica(
            DBInstanceIdentifier=read_replica_identifier,
            SourceDBInstanceIdentifier=db_instance_identifier
        )
        print(f"Read replica {read_replica_identifier} successfully created.")
        return {"status": "success", "details": response}
    except Exception as e:
        # Log and return error details if creation fails
        print(f"Error creating read replica: {e}")
        return {"status": "error", "details": str(e)}
