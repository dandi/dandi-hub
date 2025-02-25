#!/bin/bash

if [ -z "${TF_VAR_github_client_id-}" ]; then
   echo "Must provide github client id env var. Exiting...."
   exit 1
fi

if [ -z "${TF_VAR_github_client_secret-}" ]; then
   echo "Must provide github client secret env var. Exiting...."
   exit 1
fi
if [ -z "${TF_VAR_dandi_api_credentials-}" ]; then
   echo "Must provide dandi api credentials env var. Exiting...."
   exit 1
fi
