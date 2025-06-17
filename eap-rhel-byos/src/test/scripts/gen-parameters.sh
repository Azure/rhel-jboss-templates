#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location vmName adminUsername password virtualNetworkResourceGroupName storageAccountName storageAccountResourceGroupName jbossEAPUserName jbossEAPPassword rhsmUserName rhsmPassword rhsmPoolEAP rhsmPoolRHEL enableDB databaseType jdbcDataSourceJNDIName dsConnectionURL dbUser dbPassword jdkVersion gracefulShutdownTimeout enablePswlessConnection dbIdentity

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/rhel-jboss-templates/${testbranchName}/eap-rhel-byos/src/main/"
        },
        "location": {
            "value": "${location}"
        },
        "vmName": {
            "value": "${vmName}"
        },
        "adminUsername": {
            "value": "${adminUsername}"
        },
        "authenticationType": {
            "value": "password"
        },
        "adminPasswordOrSSHKey": {
            "value": "${password}"
        },
        "vmSize": {
            "value": "Standard_DS2_v2"
        },
        "virtualNetworkNewOrExisting": {
            "value": "new"
        },
        "virtualNetworkName": {
            "value": "VirtualNetwork"
        },
        "addressPrefixes": {
            "value": [
                "10.0.0.0/16"
            ]
        },
        "subnetName": {
            "value": "Subnet-1"
        },
        "subnetPrefix": {
            "value": "10.0.0.0/24"
        },
        "virtualNetworkResourceGroupName": {
            "value": "${virtualNetworkResourceGroupName}"
        },
        "bootDiagnostics": {
            "value": "on"
        },
        "storageNewOrExisting": {
            "value": "New"
        },
        "storageAccountName": {
            "value": "${storageAccountName}"
        },
        "storageAccountKind": {
            "value": "Storage"
        },
        "storageAccountResourceGroupName": {
            "value": "${storageAccountResourceGroupName}"
        },
        "jbossEAPUserName": {
            "value": "${jbossEAPUserName}"
        },
        "jbossEAPPassword": {
            "value": "${jbossEAPPassword}"
        },
        "rhsmUserName": {
            "value": "${rhsmUserName}"
        },
        "rhsmPassword": {
            "value": "${rhsmPassword}"
        },
        "rhsmPoolEAP": {
            "value": "${rhsmPoolEAP}"
        },
        "rhsmPoolRHEL": {
            "value": "${rhsmPoolRHEL}"
        },
        "enableDB": {
            "value": ${enableDB}
        },
        "databaseType": {
            "value": "${databaseType}"
        },
        "jdbcDataSourceJNDIName": {
            "value": "${jdbcDataSourceJNDIName}"
        },
        "dsConnectionURL": {
            "value": "${dsConnectionURL}"
        },
        "dbUser": {
            "value": "${dbUser}"
        },
        "dbPassword": {
            "value": "${dbPassword}"
        },
        "jdkVersion": {
            "value": "${jdkVersion}"
        },
        "gracefulShutdownTimeout": {
            "value": "${gracefulShutdownTimeout}"
        },
        "enablePswlessConnection": {
            "value": ${enablePswlessConnection}
        },
        "dbIdentity": {
            "value": ${dbIdentity}
        }
    }
}
EOF
