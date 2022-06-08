#!/usr/bin/env bash
set -Eeuo pipefail

#read arguments from stdin
read parametersPath gitUserName testbranchName location vmName asName adminUsername password enableLb numberOfInstances operatingMode virtualNetworkResourceGroupName bootStorageAccountName storageAccountResourceGroupName jbossEAPUserName jbossEAPPassword rhsmUserName rhsmPassword rhsmPoolEAP userAssignedManagedIdentity
 
cat <<EOF > ${parametersPath}
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/rhel-jboss-templates/${testbranchName}/eap74-rhel8-payg-multivm/"
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
        "enableLoadBalancer": {
            "value": "${enableLb}"
        },
        "vmSize": {
            "value": "Standard_DS2_v2"
        },
        "numberOfInstances": {
            "value": ${numberOfInstances}
        },
        "operatingMode": {
            "value": "${operatingMode}"
        },
        "numberOfServerInstances": {
            "value": 2
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
        "identity": {
            "value": {
                "type": "UserAssigned",
                "userAssignedIdentities": {
                    "${userAssignedManagedIdentity}": {}
                }
            }
        }
    }
}
EOF
