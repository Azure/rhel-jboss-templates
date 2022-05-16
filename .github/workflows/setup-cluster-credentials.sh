#!/usr/bin/env bash
################################################
# This script is invoked by a human who:
# - has done az login.
# - can create repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
#
# This script initializes the repo from which this file is was cloned
# with the necessary secrets to run the workflows.
#
# Script design taken from https://github.com/microsoft/NubesGen.
#
################################################

################################################
# Set environment variables - the main variables you might want to configure.
#
# Three letters to disambiguate names.
DISAMBIG_PREFIX=
# The location of the resource group. For example `eastus`. Leave blank to use your default location.
LOCATION=
RHSM_PASSWORD=
RHSM_USERNAME=
RHSM_POOL=
OWNER_REPONAME=
VM_PASSWORD=
JBOSS_EAP_USER_PASSWORD=
SLEEP_VALUE=30s
# User name for preceding GitHub account.
USER_NAME=
# User Email of GitHub acount to access GitHub repository.
USER_EMAIL=
# Personal token for preceding GitHub account.
GIT_TOKEN=

# End set environment variables
################################################


set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

read -r -p "Enter a disambiguation prefix (try initials with a sequence number, such as ejb01): " DISAMBIG_PREFIX

if [ "$DISAMBIG_PREFIX" == '' ] ; then
    msg "${RED}You must enter a disambiguation prefix."
    exit 1;
fi

# get RHSM_USERNAME if not set at the beginning of this file
if [ "$RHSM_USERNAME" == '' ] ; then
    read -r -p "Enter RHSM userid: " RHSM_USERNAME
fi

# get RHSM_PASSWORD if not set at the beginning of this file
if [ "$RHSM_PASSWORD" == '' ] ; then
    read -r -p "Enter password for preceding RHSM userid: " RHSM_PASSWORD
fi

# get RHSM_POOL if not set at the beginning of this file
if [ "$RHSM_POOL" == '' ] ; then
    read -r -p "Enter RHSM pool secret: " RHSM_POOL
fi

# get JBOSS_EAP_USER_PASSWORD if not set at the beginning of this file
if [ "$JBOSS_EAP_USER_PASSWORD" == '' ] ; then
    read -r -p "Enter password for jbossadmin user: " JBOSS_EAP_USER_PASSWORD
fi

# get VM_PASSWORD if not set at the beginning of this file
if [ "$VM_PASSWORD" == '' ] ; then
    read -r -p "Enter password for vm azureadmin user: " VM_PASSWORD
fi

# get USER_EMAIL if not set at the beginning of this file
if [ "$USER_EMAIL" == '' ] ; then
    read -r -p "Enter user Email of GitHub acount to access GitHub repository: " USER_EMAIL
fi

# get USER_NAME if not set at the beginning of this file
if [ "$USER_NAME" == '' ] ; then
    read -r -p "Enter user name of GitHub account: " USER_NAME
fi

# get GIT_TOKEN if not set at the beginning of this file
if [ "$GIT_TOKEN" == '' ] ; then
    read -r -p "Enter personal token of GitHub account: " GIT_TOKEN
fi

# get OWNER_REPONAME if not set at the beginning of this file
if [ "$OWNER_REPONAME" == '' ] ; then
    read -r -p "Enter owner/reponame (blank for upsteam of current fork): " OWNER_REPONAME
fi

if [ -z "${OWNER_REPONAME}" ] ; then
    GH_FLAGS=""
else
    GH_FLAGS="--repo ${OWNER_REPONAME}"
fi

DISAMBIG_PREFIX=${DISAMBIG_PREFIX}`date +%m%d`
SERVICE_PRINCIPAL_NAME=${DISAMBIG_PREFIX}sp
USER_ASSIGNED_MANAGED_IDENTITY_NAME=${DISAMBIG_PREFIX}u

# get default location if not set at the beginning of this file
if [ "$LOCATION" == '' ] ; then
    {
      az config get defaults.location --only-show-errors > /dev/null 2>&1
      LOCATION_DEFAULTS_SETUP=$?
    } || {
      LOCATION_DEFAULTS_SETUP=0
    }
    # if no default location is set, fallback to "eastus"
    if [ "$LOCATION_DEFAULTS_SETUP" -eq 1 ]; then
      LOCATION=eastus
    else
      LOCATION=$(az config get defaults.location --only-show-errors | jq -r .value)
    fi
fi

# Check AZ CLI status
msg "${GREEN}(1/6) Checking Azure CLI status...${NOFORMAT}"
{
  az > /dev/null
} || {
  msg "${RED}Azure CLI is not installed."
  msg "${GREEN}Go to https://aka.ms/nubesgen-install-az-cli to install Azure CLI."
  exit 1;
}
{
  az account show > /dev/null
} || {
  msg "${RED}You are not authenticated with Azure CLI."
  msg "${GREEN}Run \"az login\" to authenticate."
  exit 1;
}

msg "${YELLOW}Azure CLI is installed and configured!"

# Check GitHub CLI status
msg "${GREEN}(2/6) Checking GitHub CLI status...${NOFORMAT}"
USE_GITHUB_CLI=false
{
  gh auth status && USE_GITHUB_CLI=true && msg "${YELLOW}GitHub CLI is installed and configured!"
} || {
  msg "${YELLOW}Cannot use the GitHub CLI. ${GREEN}No worries! ${YELLOW}We'll set up the GitHub secrets manually."
  USE_GITHUB_CLI=false
}

# Execute commands
msg "${GREEN}(3/6) Create service principal and Azure credentials ${SERVICE_PRINCIPAL_NAME}"
SUBSCRIPTION_ID=$(az account show --query id --output tsv --only-show-errors)

### AZ ACTION CREATE

SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 -w0)
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

### AZ ACTION CREATE

msg "${GREEN}(4/6) Create User assigned managed identity ${USER_ASSIGNED_MANAGED_IDENTITY_NAME}"
az group create --name ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --location ${LOCATION}
az identity create --name ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --location ${LOCATION} --resource-group ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --subscription ${SUBSCRIPTION_ID}
USER_ASSIGNED_MANAGED_IDENTITY_ID_NOT_ESCAPED=$(az identity show --name ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --resource-group ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --query id)

### AZ ACTION MUTATE

msg "${GREEN}(5/6) Grant Contributor role in subscription scope to ${USER_ASSIGNED_MANAGED_IDENTITY_NAME}. Sleeping for ${SLEEP_VALUE} first."
sleep ${SLEEP_VALUE}
ASSIGNEE_OBJECT_ID=$(az identity show --name ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --resource-group ${USER_ASSIGNED_MANAGED_IDENTITY_NAME} --query principalId)
# strip quotes
ASSIGNEE_OBJECT_ID=${ASSIGNEE_OBJECT_ID//\"/}
az role assignment create --role Contributor --assignee-principal-type ServicePrincipal --assignee-object-id ${ASSIGNEE_OBJECT_ID} --subscription ${SUBSCRIPTION_ID} --scope /subscriptions/${SUBSCRIPTION_ID}

# https://stackoverflow.com/questions/13210880/replace-one-substring-for-another-string-in-shell-script
USER_ASSIGNED_MANAGED_IDENTITY_ID=${USER_ASSIGNED_MANAGED_IDENTITY_ID_NOT_ESCAPED//\//\\/}
# remove leading and trailing quote
USER_ASSIGNED_MANAGED_IDENTITY_ID=${USER_ASSIGNED_MANAGED_IDENTITY_ID//\"/}

msg "${GREEN}(6/6) Create secrets in GitHub"
if $USE_GITHUB_CLI; then
  {
    msg "${GREEN}Using the GitHub CLI to set secrets.${NOFORMAT}"
    gh ${GH_FLAGS} secret set AZURE_CREDENTIALS -b"${AZURE_CREDENTIALS}"
    msg "${YELLOW}\"AZURE_CREDENTIALS\""
    msg "${GREEN}${AZURE_CREDENTIALS}"
    gh ${GH_FLAGS} secret set JBOSS_EAP_USER_PASSWORD -b"${JBOSS_EAP_USER_PASSWORD}"
    gh ${GH_FLAGS} secret set VM_PASSWORD -b"${VM_PASSWORD}"
    gh ${GH_FLAGS} secret set RHSM_PASSWORD -b"${RHSM_PASSWORD}"
    gh ${GH_FLAGS} secret set RHSM_POOL -b"${RHSM_POOL}"
    gh ${GH_FLAGS} secret set RHSM_USERNAME -b"${RHSM_USERNAME}"
    gh ${GH_FLAGS} secret set SERVICE_PRINCIPAL -b"${SERVICE_PRINCIPAL}"
    gh ${GH_FLAGS} secret set USER_EMAIL -b"${USER_EMAIL}"
    gh ${GH_FLAGS} secret set USER_NAME -b"${USER_NAME}"
    gh ${GH_FLAGS} secret set GIT_TOKEN -b"${GIT_TOKEN}"
    msg "${YELLOW}\"SERVICE_PRINCIPAL\""
    msg "${GREEN}${SERVICE_PRINCIPAL}"
    gh ${GH_FLAGS} secret set USER_ASSIGNED_MANAGED_IDENTITY_ID -b"${USER_ASSIGNED_MANAGED_IDENTITY_ID}"
    msg "${YELLOW}\"USER_ASSIGNED_MANAGED_IDENTITY_ID\""
    msg "${GREEN}${USER_ASSIGNED_MANAGED_IDENTITY_ID}"
    msg "${YELLOW}\"DISAMBIG_PREFIX\""
    msg "${GREEN}${DISAMBIG_PREFIX}"
  } || {
    USE_GITHUB_CLI=false
  }
fi
if [ $USE_GITHUB_CLI == false ]; then
  msg "${NOFORMAT}======================MANUAL SETUP======================================"
  msg "${GREEN}Using your Web browser to set up secrets..."
  msg "${NOFORMAT}Go to the GitHub repository you want to configure."
  msg "${NOFORMAT}In the \"settings\", go to the \"secrets\" tab and the following secrets:"
  msg "(in ${YELLOW}yellow the secret name and${NOFORMAT} in ${GREEN}green the secret value)"
  msg "${YELLOW}\"AZURE_CREDENTIALS\""
  msg "${GREEN}${AZURE_CREDENTIALS}"
  msg "${YELLOW}\"JBOSS_EAP_USER_PASSWORD\""
  msg "${GREEN}${JBOSS_EAP_USER_PASSWORD}"
  msg "${YELLOW}\"VM_PASSWORD\""
  msg "${GREEN}${VM_PASSWORD}"
  msg "${YELLOW}\"RHSM_PASSWORD\""
  msg "${GREEN}${RHSM_PASSWORD}"
  msg "${YELLOW}\"RHSM_USERNAME\""
  msg "${GREEN}${RHSM_USERNAME}"
  msg "${YELLOW}\"SERVICE_PRINCIPAL\""
  msg "${GREEN}${SERVICE_PRINCIPAL}"
  msg "${YELLOW}\"USER_ASSIGNED_MANAGED_IDENTITY_ID\""
  msg "${GREEN}${USER_ASSIGNED_MANAGED_IDENTITY_ID}"
  msg "${YELLOW}\"RHSM_POOL\""
  msg "${GREEN}${RHSM_POOL}"
  msg "${YELLOW}\"DISAMBIG_PREFIX\""
  msg "${GREEN}${DISAMBIG_PREFIX}"
  msg "${YELLOW}\"USER_EMAIL\""
  msg "${GREEN}${USER_EMAIL}"
  msg "${YELLOW}\"USER_NAME\""
  msg "${GREEN}${USER_NAME}"
  msg "${YELLOW}\"GIT_TOKEN\""
  msg "${GREEN}${GIT_TOKEN}"
  msg "${NOFORMAT}========================================================================"
fi
msg "${GREEN}Secrets configured"