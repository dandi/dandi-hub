#!/bin/bash
# Derived from Data On EKS under Apache License 2.0.
# Source: https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub
# See LICENSE file in the root directory of this source code or at http://www.apache.org/licenses/LICENSE-2.0.html.


# Check if environment is provided
if [ -z "$1" ]; then
  echo "Usage: ./install.sh <environment>"
  exit 1
fi

source ./ensure_vars.sh


ENV=$1
ENV_DIR="envs/$ENV"
VARFILE="$ENV_DIR/terraform.tfvars"
BACKEND_FILE="$ENV_DIR/backend.tf"

source "$ENV_DIR/enforce-account.sh"

# Check if the environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist."
  exit 1
fi

# Initialize Terraform with the local backend configuration for the specified environment
echo "Initializing ..."
terraform init -backend-config="$ENV_DIR/backend.tf" -var-file="$VARFILE" || echo "\"terraform init\" failed"

# Select or create the workspace
terraform workspace select $ENV || terraform workspace new $ENV

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

Final apply to catch any remaining resources
echo "Applying remaining resources..."
apply_output=$(terraform apply -auto-approve -var-file="$VARFILE" 2>&1 | tee /dev/tty)
if [[ ${PIPESTATUS[0]} -eq 0 && $apply_output == *"Apply complete"* ]]; then
  echo "SUCCESS: Terraform apply of all modules completed successfully"
else
  echo "FAILED: Terraform apply of all modules failed"
  exit 1
fi

echo "If you need to hook this up to DNS (Route 53) use this value:" kubectl get svc/proxy-public -n jupyterhub --output jsonpath='{.status.loadBalancer.ingress[].hostname}'
