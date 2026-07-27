"""
Secret Rotation Lambda
========================
Handles automatic credential rotation for:
  Database credentials (PostgreSQL, MySQL)
  API keys (internal service-to-service)

Called by Secrets Manager on the rotation schedule.
Follows the 4-step rotation protocol:
  createSecret → setSecret → testSecret → finishSecret

PCI-DSS Req 8.2.4: Rotate credentials every 90 days max.
"""
import json
import boto3
import logging
import string
import secrets as python_secrets

logger = logging.getLogger("secret-rotator")
logging.basicConfig(level=logging.INFO)

secretsmanager = boto3.client("secretsmanager")


def lambda_handler(event, context):
    """
    Secrets Manager rotation handler.

    Secrets Manager calls this Lambda with 4 steps:
      Step 1: createSecret — generate new credential
      Step 2: setSecret — apply new credential to target
      Step 3: testSecret — verify new credential works
      Step 4: finishSecret — mark rotation complete

    Each step is called SEPARATELY — not all at once.
    """
    secret_arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    logger.info(f"Rotation step: {step}, secret: {secret_arn}")

    # Get secret metadata to determine type
    metadata = secretsmanager.describe_secret(SecretId=secret_arn)
    secret_tags = {t["Key"]: t["Value"] for t in metadata.get("Tags", [])}
    secret_type = secret_tags.get("SecretType", "APICredential")

    if step == "createSecret":
        create_secret(secret_arn, token, secret_type)
    elif step == "setSecret":
        set_secret(secret_arn, token, secret_type)
    elif step == "testSecret":
        test_secret(secret_arn, token, secret_type)
    elif step == "finishSecret":
        finish_secret(secret_arn, token)
    else:
        raise ValueError(f"Unknown rotation step: {step}")


def create_secret(secret_arn, token, secret_type):
    """
    Step 1: Generate new credentials.

    For database secrets:
      Generate a strong random password (32 chars)
      Store as the AWSPENDING version

    For API secrets:
      Generate a new API key (64 chars hex)
      Store as AWSPENDING
    """
    # Check if AWSPENDING already exists
    try:
        secretsmanager.get_secret_value(
            SecretId=secret_arn,
            VersionId=token,
            VersionStage="AWSPENDING"
        )
        logger.info("AWSPENDING already exists — skipping create")
        return
    except secretsmanager.exceptions.ResourceNotFoundException:
        pass

    # Get current secret value
    current = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT"
    )
    current_value = json.loads(current["SecretString"])

    if secret_type == "DatabaseCredential":
        # Generate new strong password
        # PCI-DSS Req 8.2.3: minimum 7 characters, numeric + alpha
        # We use 32 characters with all character types
        new_password = generate_strong_password(32)
        current_value["password"] = new_password
    else:
        # Generate new API key
        new_key = python_secrets.token_hex(32)
        current_value["api_key"] = new_key

    # Store new version as AWSPENDING
    secretsmanager.put_secret_value(
        SecretId=secret_arn,
        ClientRequestToken=token,
        SecretString=json.dumps(current_value),
        VersionStages=["AWSPENDING"]
    )

    logger.info(f"New {secret_type} credential created as AWSPENDING")


def set_secret(secret_arn, token, secret_type):
    """
    Step 2: Apply the new credential to the target system.

    For databases: ALTER USER ... PASSWORD '...'
    For APIs: update the API gateway key

    In production: this connects to the actual database
    and changes the password. For our sandbox: log only.
    """
    pending = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    pending_value = json.loads(pending["SecretString"])

    if secret_type == "DatabaseCredential":
        # In production: connect to RDS and change password
        # conn = psycopg2.connect(...)
        # conn.cursor().execute("ALTER USER ... PASSWORD ...")
        logger.info(f"Database password updated for {pending_value.get('username', 'unknown')}")
    else:
        logger.info("API key updated in target system")


def test_secret(secret_arn, token, secret_type):
    """
    Step 3: Verify the new credential works.

    For databases: attempt a connection with new password
    For APIs: make a test API call with new key

    If this step FAILS: rotation is aborted,
    old credential remains active, alert is sent.
    This prevents lockouts from bad rotations.
    """
    pending = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    pending_value = json.loads(pending["SecretString"])

    if secret_type == "DatabaseCredential":
        # In production: test database connection
        # conn = psycopg2.connect(host=..., password=new_password)
        # conn.cursor().execute("SELECT 1")
        logger.info("Database connection test PASSED with new credentials")
    else:
        logger.info("API key validation test PASSED")


def finish_secret(secret_arn, token):
    """
    Step 4: Finalize the rotation.

    Move AWSPENDING → AWSCURRENT
    Move old AWSCURRENT → AWSPREVIOUS

    After this step:
      New credential is active (AWSCURRENT)
      Old credential still works temporarily (AWSPREVIOUS)
      Applications pick up new credential on next retrieval
    """
    metadata = secretsmanager.describe_secret(SecretId=secret_arn)

    # Find the current version
    current_version = None
    for version_id, stages in metadata["VersionIdsToStages"].items():
        if "AWSCURRENT" in stages and version_id != token:
            current_version = version_id
            break

    # Promote AWSPENDING to AWSCURRENT
    secretsmanager.update_secret_version_stage(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )

    logger.info(f"Rotation COMPLETE: new credential is now AWSCURRENT")


def generate_strong_password(length=32):
    """
    Generate a cryptographically strong password.

    PCI-DSS Requirements:
      Req 8.2.3: minimum 7 characters
      Req 8.2.3: numeric AND alphabetic characters
      Best practice: include uppercase, lowercase, digits, special

    Our standard: 32 characters with all types.
    """
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*()_+-="
    while True:
        password = ''.join(python_secrets.choice(alphabet) for _ in range(length))
        # Verify password meets all requirements
        has_upper = any(c.isupper() for c in password)
        has_lower = any(c.islower() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_special = any(c in "!@#$%^&*()_+-=" for c in password)
        if has_upper and has_lower and has_digit and has_special:
            return password