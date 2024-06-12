#!/usr/bin/env bash

set -Eeuo pipefail

source pre-check.sh

echo "tear-down-cluster-credentials.sh - Start"

# remove param the json
yq -c '.[]' "$param_file" | while read -r line; do
    name=$(echo "$line" | yq -r '.name')
    value=$(echo "$line" | yq -r '.value')
    gh secret remove $name
done

echo "tear-down-cluster-credentials.sh - Finish"



