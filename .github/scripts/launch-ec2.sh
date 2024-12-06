#!/usr/bin/env bash


# TODO Test for aws access
# Set env vars 
#   aws-region
#   EC2_SSH_KEY
#
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-088d38b423bff245f \
  --count 1 \
  --instance-type t3.micro \
  --key-name dandihub-gh-actions \
  --security-group-ids sg-0bf2dc1c2ff9c122e \
  --subnet-id subnet-0f544cca61ccd2804 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=dandihub-gh-actions}]" \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID

# allocate elastic (static) IP
export ALLOC_ID=$(aws ec2 allocate-address --query 'AllocationId' --output text)

export EIP=$(aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $ALLOC_ID \
  --query 'AssociationId' --output text)

export PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids $ALLOC_ID \
  --query 'Addresses[0].PublicIp' --output text)

# Test: execute df Command on EC2
        # uses: appleboy/ssh-action@v0.1.6
        # with:
        #   host: ${{ env.PUBLIC_IP }}
        #   username: ec2-user
        #   key: ${{ secrets.EC2_SSH_KEY }}
        #   script: |
        #     echo "Running df command on EC2 instance..."
        #     df -h
        #     echo "Command completed."
        # continue-on-error: true  # Allow the workflow to continue even if this step fails
