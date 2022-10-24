#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location vmName asName adminUsername password numberOfInstances operatingMode virtualNetworkResourceGroupName bootStorageAccountName storageAccountResourceGroupName jbossEAPUserName jbossEAPPassword rhsmUserName rhsmPassword rhsmPoolEAP rhsmPoolRHEL
 
cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/rhel-jboss-templates/${testbranchName}/eap74-rhel8-byos-multivm/"
        },
        "location": {
            "value": "${location}"
        },
        "vmName": {
            "value": "${vmName}"
        },
        "asName": {
            "value": "${asName}"
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
        "numberOfInstances": {
            "value": ${numberOfInstances}
        },
        "virtualNetworkNewOrExisting": {
            "value": "new"
        },
        "virtualNetworkName": {
            "value": "VirtualNetwork"
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
        "virtualNetworkResourceGroupName": {
            "value": "${virtualNetworkResourceGroupName}"
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
        "bootStorageReplication": {
            "value": "Standard_LRS"
        },
        "storageAccountKind": {
            "value": "Storage"
        },
        "storageAccountResourceGroupName": {
            "value": "${storageAccountResourceGroupName}"
        },
        "operatingMode": {
            "value": "${operatingMode}"
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
        "enableAppGWIngress": {
            "value": true
        }
    }
}
EOF
