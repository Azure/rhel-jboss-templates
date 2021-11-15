[![Validate Deployment Templates](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml/badge.svg)](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml)

This repo has been created using the sample templates from https://github.com/Azure/azure-quickstart-templates

## Build zipped offers
1. Clean up the folder offers. This step is optional.
2. Execute ./GenerateOffers.ps1
    1. This powershell script will iterate through all the folders which have eap in it's name.
    2. For each folder, it'll add all the files except parameters file to a zip folder.
    3. It will store the zip inside offers directory.
3. These zip files from the offers directory can then be published.


## Deploying from local machine

1. Run Connect-AzAccount to login
2. Run Set-AzContext -Subscription \<subscriptionid>

create a parameters file  

    .<offer name>
        |-azuredeploy.parameters.dev.json

This file should contain values for all the parameters

    {
    "location": {
        "value": "southeastasia"
    },
    "vmName": {
        "value": "jbvm"
    },
    "asName": {
        "value": "jbas"
    },
    "adminUsername": {
        "value": "azlinux"
    },
    "authenticationType": {
        "value": "sshPublicKey"
    },
    "adminPasswordOrSSHKey": {
        "value": "<Public ssh key>"
    },
    "vmSize": {
        "value": "Standard_DS2_v2"
    },
    "numberOfInstances": {
        "value": 3
    },
    "virtualNetworkNewOrExisting": {
        "value": "existing"
    },
    "virtualNetworkName": {
        "value": "pb-rg2-vnet"
    },
    "addressPrefixes": {
        "value": [
        "172.18.0.0/16"
        ]
    },
    "subnetName": {
        "value": "default"
    },
    "subnetPrefix": {
        "value": "172.18.0.0/24"
    },
    "virtualNetworkResourceGroupName": {
        "value": "pbasnal-rg2"
    },
    "bootDiagnostics": {
        "value": "on"
    },
    "bootStorageNewOrExisting": {
        "value": "existing"
    },
    "bootStorageAccountName": {
        "value": "jbbootdiag"
    },
    "bootStorageReplication": {
        "value": "Standard_RAGRS"
    },
    "bootStorageAccountResourceGroup": {
        "value": "pbasnal-rg"
    },
    "jbossEAPUserName": {
        "value": "azlinux"
    },
    "jbossEAPPassword": {
        "value": "********"
    },
    "rhsmUserName": {
        "value": "pbasnal-msft"
    },
    "rhsmPassword": {
        "value": "******"
    },
    "rhsmPoolEAP": {
        "value": ""
    },
    "rhsmPoolRHEL": {
        "value": ""
    }
    }

```powershell
.\Deploy-AzTemplate.ps1 -ArtifactStagingDirectory .\eap73-rhel8-payg-multivm -ResourceGroupLocation southeastasia -dev -UploadArtifacts
```
