#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location pullSecret aadClientId aadClientSecret aadObjectId rpObjectId vmSize workerVmSize workerCount conRegAccUserName conRegAccPwd createCluster clusterName clusterRGName
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
        "vmSize": {
            "value": "${vmSize}"
        },
        "workerVmSize": {
            "value": "${workerVmSize}"
        },
        "workerCount": {
            "value": ${workerCount}
        },
        "deployApplication": {
            "value": true
        },
        "srcRepoUrl": {
            "value": "https://github.com/azure-javaee/eap-on-aro-helloworld.git"
        },
        "srcRepoRef": {
            "value": "eap-8.0.x"
        },
        "srcRepoDir": {
            "value": "/"
        },
        "appReplicas": {
            "value": 1
        },
        "conRegAccUserName": {
            "value": "${conRegAccUserName}"
        },
        "conRegAccPwd": {
            "value": "${conRegAccPwd}"
        },
        "createCluster": {
            "value": ${createCluster}
        },
        "clusterName": {
            "value": "${clusterName}"
        },
        "clusterRGName": {
            "value": "${clusterRGName}"
        }
    }
}
EOF
