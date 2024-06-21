#!/usr/bin/env bash

################################################
# This script is invoked by a human who:
# - can remove repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
#
# This script initializes the repo from which this file is was cloned
# with the necessary secrets to run the workflows.
# Steps to run the Script:
# 1. Run gh auth login.
# 2. Clone the repository.
# 3. Run the script with the following command:
#    bash .github/workflows/tear-down-cluster-credentials.sh
# 4. The script will remove the required secrets in the repository.
# 5. Check the repository secrets to verify that the secrets are removed.
################################################

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



