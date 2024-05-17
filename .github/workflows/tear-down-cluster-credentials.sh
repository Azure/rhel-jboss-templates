#!/usr/bin/env bash

source pre-check.sh

echo "tear-down-cluster-credentials.sh - Start"

# remove param the json
jq -c '.[]' $param_file | while read line; do
    name=$(echo $line | jq -r  '.name')
    echo "gh secret remove $name ............"
    gh secret remove $name
done

echo "tear-down-cluster-credentials.sh - Finish"


