# Derived from Data On EKS under Apache License 2.0.
# Source: https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub
# See LICENSE file in the root directory of this source code or at http://www.apache.org/licenses/LICENSE-2.0.html.

#!/bin/bash
set -o errexit
set -o pipefail

# Check if environment is provided
if [ -z "$1" ]; then
  echo "Usage: ./cleanup.sh <environment>"
  exit 1
fi



ENV=$1
ENV_DIR="envs/$ENV"
VARFILE="$ENV_DIR/terraform.tfvars"
BACKEND_FILE="$ENV_DIR/s3.tfbackend"

source ./scripts/ensure-vars.sh

# Check if the environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist."
  exit 1
fi

# Initialize Terraform with the local backend configuration for the specified environment
echo "Initializing ..."
terraform init -backend-config="$BACKEND_FILE" -var-file="$VARFILE" || echo "\"terraform init\" failed"

terraform workspace select "$ENV"

targets=(
  "module.eks_data_addons"
  "module.eks_blueprints_addons"
  "module.eks"
  "module.vpc"
)

#-------------------------------------------
# Helpful to delete the stuck in "Terminating" namespaces
# Rerun the cleanup.sh script to detect and delete the stuck resources
#-------------------------------------------
terminating_namespaces=$(kubectl get namespaces --field-selector status.phase=Terminating -o json | jq -r '.items[].metadata.name')

# If there are no terminating namespaces, exit the script
if [[ -z $terminating_namespaces ]]; then
    echo "No terminating namespaces found"
fi

for ns in $terminating_namespaces; do
    echo "Terminating namespace: $ns"
    kubectl get namespace "$ns" -o json | sed 's/"kubernetes"//' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
done

#-------------------------------------------
# Terraform destroy per module target
#-------------------------------------------
for target in "${targets[@]}"
do
  destroy_output=$(terraform destroy -target="$target" -var-file="$VARFILE" -auto-approve | tee /dev/tty)
  if [[ ${PIPESTATUS[0]} -eq 0 && $destroy_output == *"Destroy complete!"* ]]; then
    echo "SUCCESS: Terraform destroy of $target completed successfully"
  else
    echo "FAILED: Terraform destroy of $target failed"
    exit 1
  fi
done

#-------------------------------------------
# Terraform destroy full
#-------------------------------------------
destroy_output=$(terraform destroy  -target="$target" -var-file="$VARFILE" -auto-approve | tee /dev/tty)
if [[ ${PIPESTATUS[0]} -eq 0 && $destroy_output == *"Destroy complete!"* ]]; then
  echo "SUCCESS: Terraform destroy of all targets completed successfully"
else
  echo "FAILED: Terraform destroy of all targets failed"
  exit 1
fi
