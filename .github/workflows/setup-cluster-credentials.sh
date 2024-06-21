#!/usr/bin/env bash

################################################
# This script is invoked by a human who:
# - has done az login.
# - can create repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
#
# This script initializes the repo from which this file is was cloned
# with the necessary secrets to run the workflows.
# Steps to run the Script:
# 1. Run az login.
# 2. Run gh auth login.
# 3. Clone the repository.
# 4. Prepare the .github/resource/credentials-params.yaml file with the required parameters.
# 5. Run the script with the following command:
#    bash .github/workflows/setup-cluster-credentials.sh
# 6. The script will set the required secrets in the repository.
# 7. Check the repository secrets to verify that the secrets are set.
################################################

set -Eeuo pipefail

source pre-check.sh

# ANSI color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "setup-cluster-credentials.sh - Start"

# Function to print error messages in red
print_error() {
    local message=$1
    echo -e "${RED}Error: ${message}${NC}"
}

check_parameters() {
    echo "Checking parameters..."
    local has_empty_value=0

    while IFS= read -r line; do
        name=$(echo "$line" | yq -r '.name')
        value=$(echo "$line" | yq -r '.value')

       if [ -z "$value" ] || [ "$value" == "null" ]; then
            print_error "The parameter '$name' has an empty/null value. Please provide a valid value."
            has_empty_value=1
            break
        else
            echo "Name: $name, Value: $value"
        fi
    done < <(yq -c '.[]' "$param_file")

    echo "return $has_empty_value"
    return $has_empty_value
}

# Function to set values from YAML
set_values() {
    echo "Setting values..."
    yq -c '.[]' "$param_file" | while read -r line; do
        name=$(echo "$line" | yq -r '.name')
        value=$(echo "$line" | yq -r '.value')
        gh secret set "$name" -b"${value}"
    done
}

# Main script execution
main() {
    if check_parameters; then
        echo "All parameters are valid."
        set_values
    else
        echo "Parameter check failed. Exiting."
        exit 1
    fi

    echo "setup-cluster-credentials.sh - Finish"
}

# Run the main function
main
