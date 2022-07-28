#!/usr/bin/env bash
set -Eeuo pipefail

function echo_stderr() {
    echo "$@" 1>&2
    # The function is used for scripts running within Azure Deployment Script
    # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
    echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/errors.log
}

function echo_stdout() {
    echo "$@"
    # The function is used for scripts running within Azure Deployment Script
    # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
    echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/debug.log
}

#Validate teminal status with $?, exit with exception if errors happen.
# $1 - error message
# $2 -  root cause message
function validate_status() {
    if [ $? != 0 ]; then
        echo_stderr "Errors happen during: $1." $2
        exit 1
    else
        echo_stdout "$1"
    fi
}

#Validate teminal status with $?, exit with exception if errors happen.
# $1 - error message
# $2 -  root cause message
function validate_status() {
    if [ $? != 0 ]; then
        echo_stderr "Errors happen during: $1." $2
        exit 1
    else
        echo_stdout "$1"
    fi
}

# Validate User Assigned Managed Identity
# Check points:
#   - the identity is User Assigned Identity, if not, exit with error.
#   - the identity is assigned with Contributor or Owner role, if not, exit with error.
function validate_user_assigned_managed_identity() {
    # AZ_SCRIPTS_USER_ASSIGNED_IDENTITY
    local uamiType=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "type" -o tsv)
    validate_status "query resource type of ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}" "The user managed identity may not exist, please check."
    if [[ "${uamiType}" != "${userManagedIdentityType}" ]]; then
        echo_stderr "You must use User Assigned Managed Identity, please follow the document to create one: https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal?WT.mc_id=Portal-Microsoft_Azure_CreateUIDef"
        exit 1
    fi

    echo_stdout "query principal Id of the User Assigned Identity."
    local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)

    echo_stdout "check if the user assigned managed identity has Contributor or Owner role."
    local roleLength=$(az role assignment list --assignee ${principalId} |
        jq '[.[] | select(.roleDefinitionName=="Contributor" or .roleDefinitionName=="Owner")] | length')
    if [ ${roleLength} -lt 1 ]; then
        echo_stderr "You must grant the User Assigned Managed Identity with at least Contributor role. Please check ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}"
        exit 1
    fi

    echo_stdout "Check User Assigned Identity: passed!"
}

# Validate compute resources
# Check points:
#   - there is enough resource for VM
# Example to list the vm usage:
# az vm list-usage --location "East US" -o table
# Name                                      CurrentValue    Limit
# ----------------------------------------  --------------  -------
# Availability Sets                         0               2500
# Total Regional vCPUs                      2               200
# Virtual Machines                          1               25000
# Virtual Machine Scale Sets                0               2500
# Dedicated vCPUs                           0               3000
# Cloud Services                            0               2500
# Total Regional Low-priority vCPUs         0               100
# Standard DSv2 Family vCPUs                0               100
# Standard Av2 Family vCPUs                 2               100
# Basic A Family vCPUs                      0               100
# Standard A0-A7 Family vCPUs               0               200
# Standard A8-A11 Family vCPUs              0               100
# Standard D Family vCPUs                   0               100
# Standard Dv2 Family vCPUs                 0               100
# Standard DS Family vCPUs                  0               100
# Standard G Family vCPUs                   0               100
# Standard GS Family vCPUs                  0               100
# Standard F Family vCPUs                   0               100
# Standard FS Family vCPUs                  0               100
# ... ...
function validate_compute_resources() {
    # Resource for RHEL machine
    # 2 Standard Av2 Family vCPUs

    # query total cores
    local vmUsage=$(az vm list-usage -l ${location} -o json)
    local totalCPUs=$(echo ${vmUsage} | jq '.[] | select(.name.value=="cores") | .limit' | tr -d "\"")
    local currentCPUs=$(echo ${vmUsage} | jq '.[] | select(.name.value=="cores") | .currentValue' | tr -d "\"")

    local vmDetail=$(az vm list-skus --size ${vmSize} -l ${location} --query [0])
    local vmFamily=$(echo ${vmDetail} | jq '.family' | tr -d "\"")
    local vmCPUs=$(echo ${vmDetail} | jq '.capabilities[] | select(.name=="vCPUs") | .value' | tr -d "\"")
    vmCPUsTotal=$((vmCPUs * numberOfInstances))

    # query CPU usage of the vm family
    local familyLimit=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamily}'") | .limit' | tr -d "\"")
    local familyUsage=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamily}'") | .currentValue' | tr -d "\"")
    local requiredFamilyCPUs=$((vmCPUsTotal + familyUsage))
    # make sure thers is enough vCPUs of the family for VMs
    if [ ${requiredFamilyCPUs} -gt ${familyLimit} ]; then
        echo_stderr "It requires ${vmCPUsTotal} ${vmFamily} vCPUs to create the VMs, ${vmFamily} vCPUs quota is limited to ${familyLimit}, current usage is ${familyUsage}."
        exit 1
    else
        echo_stdout "Check compute resources: passed!"
    fi
}

# Make sure the provided satellite FQDN can be correctly resolved to an IP address
function validate_satellite_network() {
    # Checking for the resolved IP address from the end of the command output.

    resolvedIP=$(nslookup "$satelliteFqdn" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)

    # Deciding the lookup status by checking the variable has a valid IP string

    if [[ -z "$resolvedIP" ]]; then
        echo_stderr "$satelliteFqdn" lookup failure
        exit 1
    else
        echo_stdout "$satelliteFqdn" resolved to "$resolvedIP"
    fi
}

#main
location=$1
vmSize=$2
numberOfInstances=$3
connectSatellite=$4
satelliteFqdn=$5
userManagedIdentityType="Microsoft.ManagedIdentity/userAssignedIdentities"

validate_user_assigned_managed_identity

validate_compute_resources

if [[ "${connectSatellite,,}" == "true" ]]; then
    validate_satellite_network
fi
