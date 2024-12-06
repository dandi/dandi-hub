#!/usr/bin/env bash

set -e

# Check for AWS CLI and credentials
if ! command -v aws &>/dev/null; then
  echo "Error: AWS CLI is not installed. Please install it and configure your credentials."
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  echo "Error: Unable to access AWS. Ensure your credentials are configured correctly."
  exit 1
fi

# Set variables
AWS_REGION="us-east-2" # Update to your AWS region if different
KEY_NAME="dandihub-gh-actions"
SECURITY_GROUP_ID="sg-0bf2dc1c2ff9c122e"
SUBNET_ID="subnet-0f544cca61ccd2804"
AMI_ID="ami-088d38b423bff245f"

# Run EC2 instance
echo "Launching EC2 instance..."
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type t3.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=dandihub-gh-actions}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "Error: Failed to launch EC2 instance."
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to initialize
echo "Waiting for instance to reach status OK..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID

# Allocate Elastic IP
echo "Allocating Elastic IP..."
export ALLOC_ID=$(aws ec2 allocate-address \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=dandihub-gh-actions-eip}]" \
  --query 'AllocationId' \
  --output text)

if [ -z "$ALLOC_ID" ]; then
  echo "Error: Failed to allocate Elastic IP."
  exit 1
fi

echo "Elastic IP Allocation ID: $ALLOC_ID"

# Associate Elastic IP with instance
echo "Associating Elastic IP with instance..."
export EIP_ASSOC=$(aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $ALLOC_ID \
  --query 'AssociationId' \
  --output text)

if [ -z "$EIP_ASSOC" ]; then
  echo "Error: Failed to associate Elastic IP."
  exit 1
fi

# Get Elastic IP address
export PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids $ALLOC_ID \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "Elastic IP Address: $PUBLIC_IP"

# Output SSH command for convenience
echo "To connect to your instance, use:"
echo "ssh -i \$EC2_SSH_KEY ec2-user@$PUBLIC_IP"
