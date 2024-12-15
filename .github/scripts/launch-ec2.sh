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
AWS_REGION="us-east-2"
# TODO document that this key needs to be created
KEY_NAME="dandihub-gh-actions"
# TODO create if DNE
# allow gh-actions to ssh into ec2 job instance from anywhere
SECURITY_GROUP_ID="sg-0bf2dc1c2ff9c122e"
# TODO retrieve subnet id (public, created by dandi-hub eks-dandihub-public-us-east-2a)
SUBNET_ID="subnet-0f544cca61ccd2804"
AMI_ID="ami-0c80e2b6ccb9ad6d1"
EFS_ID="fs-02aac16c4c6c2dc27"
LOCAL_SCRIPTS_DIR=".github/scripts"
REMOTE_SCRIPTS_DIR="/home/ec2-user/scripts"
MOUNT_POINT="/mnt/efs"
ENV_FILE=".ec2-session.env"

# Ensure the environment file is writable
echo "# Environment variables for EC2 session" > $ENV_FILE
echo "# Auto-generated by launch script on $(date)" >> $ENV_FILE

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
echo "export INSTANCE_ID=$INSTANCE_ID" >> $ENV_FILE

# Wait for instance to initialize
echo "Waiting for instance to reach status OK..."
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

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
echo "export ALLOC_ID=$ALLOC_ID" >> $ENV_FILE

# Associate Elastic IP with instance
echo "Associating Elastic IP with instance..."
export EIP_ASSOC=$(aws ec2 associate-address \
  --instance-id "$INSTANCE_ID" \
  --allocation-id "$ALLOC_ID" \
  --query 'AssociationId' \
  --output text)

if [ -z "$EIP_ASSOC" ]; then
  echo "Error: Failed to associate Elastic IP."
  exit 1
fi

# Get Elastic IP address
export PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids "$ALLOC_ID" \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "Elastic IP Address: $PUBLIC_IP"
echo "export PUBLIC_IP=$PUBLIC_IP" >> $ENV_FILE

# Upload scripts to EC2 instance
echo "Uploading scripts to EC2 instance..."
scp -i "$EC2_SSH_KEY" -o "StrictHostKeyChecking=no" \
  $LOCAL_SCRIPTS_DIR/calculate-directory-stats.py $LOCAL_SCRIPTS_DIR/create-file-index.py \
  ec2-user@"$PUBLIC_IP":"$REMOTE_SCRIPTS_DIR/"

if [ $? -eq 0 ]; then
  echo "Scripts uploaded successfully to $REMOTE_SCRIPTS_DIR on the instance."
else
  echo "Error: Failed to upload scripts to the instance."
  exit 1
fi

# TODO automate
# eks-dandihub-efs sg is created by dandi-hub install
# this sg needs to accept incoming 2049 from the sg created for this ec2
# sg-061d875722e569724 - eks-dandihub-efs
# aws ec2 authorize-security-group-ingress \
#   --group-id sg-061d875722e569724 \
#   --protocol tcp \
#   --port 2049 \
#   --source-group $SECURITY_GROUP_ID

# Mount EFS on the EC2 instance
echo "Mounting EFS on the EC2 instance..."
ssh -i "$EC2_SSH_KEY" -o "StrictHostKeyChecking=no" ec2-user@"$PUBLIC_IP" \
  "sudo yum install -y amazon-efs-utils && \
   sudo mkdir -p $MOUNT_POINT && \
   sudo mount -t efs $EFS_ID:/ $MOUNT_POINT && \
   echo '$EFS_ID:/ $MOUNT_POINT efs defaults,_netdev 0 0' | sudo tee -a /etc/fstab && \
   echo 'EFS mounted at $MOUNT_POINT'"

# Output SSH command for convenience
echo "To connect to your instance, use:"
echo "ssh -i \$EC2_SSH_KEY ec2-user@$PUBLIC_IP"

echo "Environment variables saved to $ENV_FILE."
echo "Run 'source $ENV_FILE' to restore the environment variables."
