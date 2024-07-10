#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location vmssName adminUsername password virtualNetworkResourceGroupName bootStorageAccountName storageAccountResourceGroupName instanceCount jbossEAPUserName jbossEAPPassword enableDB databaseType jdbcDataSourceJNDIName dsConnectionURL dbUser dbPassword jdkVersion
 
cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/rhel-jboss-templates/${testbranchName}/eap74-rhel8-payg-vmss/"
        },
        "location": {
            "value": "${location}"
        },
        "vmssName": {
            "value": "${vmssName}"
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
        "virtualNetworkResourceGroupName": {
            "value": "${virtualNetworkResourceGroupName}"
        },
        "addressPrefixes": {
            "value": [
                "10.0.0.0/23"
            ]
        },
        "subnetName": {
            "value": "jboss-subnet"
        },
        "subnetPrefix": {
            "value": "10.0.0.0/28"
        },
        "subnetForAppGateway": {
            "value": "jboss-appgateway-subnet"
        },
        "subnetPrefixForAppGateway": {
            "value": "10.0.1.0/24"
        },
        "bootDiagnostics": {
            "value": "on"
        },
        "bootStorageNewOrExisting": {
            "value": "New"
        },
        "bootStorageAccountName": {
            "value": "${bootStorageAccountName}"
        },
        "storageAccountKind": {
            "value": "Storage"
        },
        "bootStorageReplication": {
            "value": "Standard_LRS"
        },
        "storageAccountResourceGroupName": {
            "value": "${storageAccountResourceGroupName}"
        },
        "instanceCount": {
            "value": ${instanceCount}
        },
        "jbossEAPUserName": {
            "value": "${jbossEAPUserName}"
        },
        "jbossEAPPassword": {
            "value": "${jbossEAPPassword}"
        },
        "enableAppGWIngress": {
            "value": true
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
        }
    }
}
EOF
