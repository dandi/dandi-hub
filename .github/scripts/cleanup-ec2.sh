#!/usr/bin/env bash

set -eu

# Load environment variables from the file if they are not already set
ENV_FILE=".ec2-session.env"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from $ENV_FILE..."
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "Warning: Environment file $ENV_FILE not found."
fi

# Ensure required environment variables are set
if [ -z "$INSTANCE_ID" ]; then
  echo "Error: INSTANCE_ID is not set. Cannot proceed with cleanup."
  exit 1
fi

if [ -z "$ALLOC_ID" ]; then
  echo "Error: ALLOC_ID is not set. Cannot proceed with cleanup."
  exit 1
fi

# Check for AWS CLI and credentials
if ! command -v aws &>/dev/null; then
  echo "Error: AWS CLI is not installed. Please install it and configure your credentials."
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  echo "Error: Unable to access AWS. Ensure your credentials are configured correctly."
  exit 1
fi

# Terminate EC2 instance
echo "Terminating EC2 instance with ID: $INSTANCE_ID..."
if aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --no-cli-pager; then
  echo "Instance termination initiated. Waiting for the instance to terminate..."
  if aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"; then
    echo "Instance $INSTANCE_ID has been successfully terminated."
  else
    echo "Warning: Instance $INSTANCE_ID may not have terminated correctly."
  fi
else
  echo "Warning: Failed to terminate instance $INSTANCE_ID. It may already be terminated."
fi

# Release Elastic IP
echo "Releasing Elastic IP with Allocation ID: $ALLOC_ID..."
if aws ec2 release-address --allocation-id "$ALLOC_ID"; then
  echo "Elastic IP with Allocation ID $ALLOC_ID has been successfully released."
else
  echo "Warning: Failed to release Elastic IP with Allocation ID $ALLOC_ID. It may already be released."
fi

# Cleanup environment file
if [ -f "$ENV_FILE" ]; then
  echo "Removing environment file $ENV_FILE..."
  rm -f "$ENV_FILE"
fi

echo "Cleanup complete."
