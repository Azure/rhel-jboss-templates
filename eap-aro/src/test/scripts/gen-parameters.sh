#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location pullSecret aadClientId aadClientSecret aadObjectId rpObjectId
pullSecret=${pullSecret//\"/\\\"}

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/rhel-jboss-templates/${testbranchName}/eap-aro/"
        },
        "location": {
            "value": "${location}"
        },
        "createCluster": {
            "value": true
        },
        "pullSecret": {
            "value": "${pullSecret}"
        },
        "aadClientId": {
            "value": "${aadClientId}"
        },
        "aadClientSecret": {
            "value": "${aadClientSecret}"
        },
        "aadObjectId": {
            "value": "${aadObjectId}"
        },
        "rpObjectId": {
            "value": "${rpObjectId}"
        },
        "deployApplication": {
            "value": false
        }
    }
}
EOF
