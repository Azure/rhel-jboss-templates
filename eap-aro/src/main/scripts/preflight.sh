#!/bin/bash

set -Euo pipefail

# Wait 60s for service principal available after creation
# See https://github.com/WASdev/azure.liberty.aro/issues/59 & https://github.com/WASdev/azure.liberty.aro/issues/79
sleep 60

MAX_RETRIES=10
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  if [[ -z "$AAD_OBJECT_ID" ]]; then
    sleep 10
    AAD_OBJECT_ID=$(az ad sp show --id ${AAD_CLIENT_ID} --query id -o tsv)
  fi

  if [[ -n "$AAD_OBJECT_ID" ]]; then
    echo "Successfully retrieved AAD_OBJECT_ID: $AAD_OBJECT_ID"
    exit 0
  fi

  ((RETRY_COUNT++))
done

result=$(jq -n -c \
    --arg AAD_OBJECT_ID "$AAD_OBJECT_ID" \
    '{AAD_OBJECT_ID: $AAD_OBJECT_ID}')
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
