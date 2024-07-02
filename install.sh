#!/bin/bash
# Derived from Data On EKS under Apache License 2.0.
# Source: https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub
# See LICENSE file in the root directory of this source code or at http://www.apache.org/licenses/LICENSE-2.0.html.

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

# TODO
# ./scripts/enforcer.sh $ENV

# TODO preface all env vars
ENV_DIR="envs/$ENV"

VARFILE="$ENV_DIR/terraform.tfvars"
BACKEND_FILE="$ENV_DIR/backend.tf"

BASE_CONFIG="envs/shared/jupyterhub.yaml"
ENV_OVERRIDE="$ENV_DIR/jupyterhub-overrides.yaml"

# TODO put a DONOTTOUCH in V
OUTPUT="$ENV_DIR/managed-jupyterhub.yaml"


# Check if the environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist."
  exit 1
fi

# Merge Overrides into managed config file
./scripts/merge-config.py $BASE_CONFIG $ENV_OVERRIDE $OUTPUT

# Ensure that $OUTPUT is not dirty (if changes, they should be committed prior to execution, except during development)
# TODO
# ./scripts/fail-dirty.sh
#
# # Validate yaml
# # TODO
#
# # Initialize Terraform with environment-provided backend configuration
# echo "Initializing ..."
# # TODO exit code if failed
# terraform init -backend-config="$ENV_DIR/backend.tf" -var-file="$VARFILE" || echo "\"terraform init\" failed"
#
# # Select or create the workspace
# terraform workspace select $ENV || terraform workspace new $ENV
#
# # List of Terraform modules to apply in sequence
# targets=(
#   "module.vpc"
#   "module.eks"
# )
#
# # Apply modules in sequence
# for target in "${targets[@]}"
# do
#   echo "Applying module $target..."
#   apply_output=$(terraform apply -target="$target" -auto-approve -var-file="$VARFILE" 2>&1 | tee /dev/tty)
#   if [[ ${PIPESTATUS[0]} -eq 0 && $apply_output == *"Apply complete"* ]]; then
#     echo "SUCCESS: Terraform apply of $target completed successfully"
#   else
#     echo "FAILED: Terraform apply of $target failed"
#     exit 1
#   fi
# done
#
# # Final apply to catch any remaining resources
# echo "Applying remaining resources..."
# apply_output=$(terraform apply -auto-approve -var-file="$VARFILE" 2>&1 | tee /dev/tty)
# if [[ ${PIPESTATUS[0]} -eq 0 && $apply_output == *"Apply complete"* ]]; then
#   echo "SUCCESS: Terraform apply of all modules completed successfully"
# else
#   echo "FAILED: Terraform apply of all modules failed"
#   exit 1
# fi
#
# # TODO route 53 aws CLI
# echo "If you need to hook this up to DNS (Route 53) use this value:" kubectl get svc/proxy-public -n jupyterhub --output jsonpath='{.status.loadBalancer.ingress[].hostname}'
