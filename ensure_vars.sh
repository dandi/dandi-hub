#!/bin/bash

if [ -z "${TF_VAR_github_client_id-}" ]; then
   echo "Must provide github client id env var. Exiting...."
   exit 1
fi

if [ -z "${TF_VAR_github_client_secret-}" ]; then
   echo "Must provide github client secret env var. Exiting...."
   exit 1
fi
if [ -z "${TF_VAR_danditoken-}" ]; then
   echo "Must provide DANDI API key. Exiting...."
   exit 1
fi
if [ -z "${HUB_DEPLOYMENT_NAME}" ]; then
   echo "Must provide HUB_DEPLOYMENT_NAME. Exiting...."
   exit 1
fi
