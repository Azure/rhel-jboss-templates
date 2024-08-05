#!/bin/bash

set -Euo pipefail

if [[ "${CREATE_CLUSTER,,}" == "true" ]]; then
  # Fail fast the deployment if object Id of the service principal is empty
  if [[ -z "$AAD_OBJECT_ID" ]]; then
    echo "The object Id of the service principal you just created is not successfully retrieved, please retry another deployment using its client id ${AAD_CLIENT_ID}." >&2
    exit 1
  fi

  # Wait 60s for service principal available after creation
  # See https://github.com/WASdev/azure.liberty.aro/issues/59 & https://github.com/WASdev/azure.liberty.aro/issues/79
  sleep 60
fi