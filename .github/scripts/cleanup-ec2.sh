#!/usr/bin/env bash

# Ensure required environment variables are set
if [ -z "$INSTANCE_ID" ]; then
  echo "Error: INSTANCE_ID is not set. Cannot proceed with cleanup."
  exit 1
fi

if [ -z "$ALLOC_ID" ]; then
  echo "Error: ALLOC_ID is not set. Cannot proceed with cleanup."
  exit 1
fi

# Terminate EC2 instance
echo "Terminating EC2 instance with ID: $INSTANCE_ID"
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
if [ $? -eq 0 ]; then
  echo "Instance termination initiated. Waiting for the instance to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
  echo "Instance $INSTANCE_ID has been terminated."
else
  echo "Error: Failed to terminate instance $INSTANCE_ID."
  exit 1
fi

# Release Elastic IP
echo "Releasing Elastic IP with Allocation ID: $ALLOC_ID"
aws ec2 release-address --allocation-id $ALLOC_ID
if [ $? -eq 0 ]; then
  echo "Elastic IP with Allocation ID $ALLOC_ID has been released."
else
  echo "Error: Failed to release Elastic IP with Allocation ID $ALLOC_ID."
  exit 1
fi

echo "Cleanup complete."
