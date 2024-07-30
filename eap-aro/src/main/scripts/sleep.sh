#!/bin/bash

set -Euo pipefail

if [[ "${CREATE_CLUSTER,,}" == "true" ]]; then
  # Wait 60s for service principal available after creation
  # See https://github.com/WASdev/azure.liberty.aro/issues/59 & https://github.com/WASdev/azure.liberty.aro/issues/79
  sleep 60
fi
