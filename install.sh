#!/bin/bash
# Derived from Data On EKS under Apache License 2.0.
# Source: https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub
# See LICENSE file in the root directory of this source code or at http://www.apache.org/licenses/LICENSE-2.0.html.

set -eu
# Check if environment is provided
if [ -z "$1" ]; then
  echo "Usage: ./install.sh <environment>"
  exit 1
fi

source ./scripts/ensure-vars.sh

# TODO check tf version
# TODO check aws cli version
# TODO check kubectl version

ENV=$1

./scripts/account-enforcer.sh $ENV

# TODO preface all env vars
ENV_DIR="envs/$ENV"

VARFILE="$ENV_DIR/terraform.tfvars"
BACKEND_FILE="$ENV_DIR/backend.tf"

BASE_CONFIG="envs/shared/jupyterhub.yaml"
ENV_OVERRIDE="$ENV_DIR/jupyterhub-overrides.yaml"

OUTPUT="$ENV_DIR/managed-jupyterhub.yaml"


# Check if the environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist."
  exit 1
fi

./scripts/merge_config.py $BASE_CONFIG $ENV_OVERRIDE $OUTPUT

yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable}}" "$OUTPUT"
if [ $? -ne 0 ]; then
  echo "Invalid YAML file: $OUTPUT"
  exit 1
fi

if [ ! -f "$OUTPUT" ]; then
  echo "Managed jupyterhub config file not found: $OUTPUT"
  exit 1
fi

if git diff --exit-code "$OUTPUT" > /dev/null; then
  # No changes to managed config, continue
  :
else
  echo "Changes detected in $OUTPUT."
  exit 1
fi

# Initialize Terraform with environment-provided backend configuration
echo "Initializing $ENV..."
terraform init -reconfigure -backend-config="$ENV_DIR/s3.tfbackend" -var-file="$VARFILE"
terraform workspace select -or-create $ENV

# From here forward, we should continue even if there is a failure
set +e
# List of Terraform modules to apply in sequence
targets=(
  "module.vpc"
  "module.eks"
)

# Apply modules in sequence
for target in "${targets[@]}"
do
  echo "Applying module $target..."
  apply_output=$(terraform apply -target="$target" -auto-approve -var-file="$VARFILE" 2>&1 | tee /dev/tty)
  if [[ ${PIPESTATUS[0]} -eq 0 && $apply_output == *"Apply complete"* ]]; then
    echo "SUCCESS: Terraform apply of $target completed successfully"
  else
    echo "FAILED: Terraform apply of $target failed"
    exit 1
  fi
done

# Final apply to catch any remaining resources
echo "Applying remaining resources..."
apply_output=$(terraform apply -auto-approve -var-file="$VARFILE" 2>&1 | tee /dev/tty)
if [[ ${PIPESTATUS[0]} -eq 0 && $apply_output == *"Apply complete"* ]]; then
  echo "SUCCESS: Terraform apply of all modules completed successfully"
else
  echo "FAILED: Terraform apply of all modules failed"
  exit 1
fi

# Set kubeconfig to point kubectl to cluster
$(terraform output -raw configure_kubectl)

INGRESS_HOSTNAME=$(kubectl get svc/proxy-public -n jupyterhub --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo "Jupyterhub is running!"
echo "Set DNS record (Route53) to Ingress Hostname: $INGRESS_HOSTNAME"
