#!/bin/bash

CORRECT="bican"

if [ "$AWS_PROFILE" != $CORRECT ]; then
  echo "Error: Should only be deployed when AWS_PROFILE == $CORRECT, currently set to $AWS_PROFILE"
  exit 1
fi
