#!/bin/bash

declare -A ENV_TO_PROFILE=(
  ["dandi-staging"]="mcgovern"
  ["dandi"]="mcgovern"
  ["bican"]="bican"
  ["linc"]="linc"
)

if [ $# -ne 1 ]; then
  echo "Usage: $0 <environment>"
  echo "Environments: ${!ENV_TO_PROFILE[@]}"
  exit 1
fi

ENV=$1
CORRECT=${ENV_TO_PROFILE[$ENV]}

if [ -z "$CORRECT" ]; then
  echo "Error: Invalid environment '$ENV'"
  echo "Valid environments: ${!ENV_TO_PROFILE[@]}"
  exit 1
fi

if [ "$AWS_PROFILE" != "$CORRECT" ]; then
  echo "Error: Should only be deployed when AWS_PROFILE == $CORRECT, currently set to $AWS_PROFILE"
  exit 1
fi

