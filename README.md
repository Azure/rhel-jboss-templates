[![Validate Deployment Templates](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml/badge.svg?branch=master)](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml)

This repo contains JBoss EAP Marketplace templates for use on Azure Marketplace. Each subdirectory corresponds to one of the offered plans.

## Deployment Description

### Red Hat JBoss EAP on VMs

There are three different types of EAP on VM offers based on their outcomes.

#### JBoss EAP standalone on RHEL VM(PAYG/BYOS)

[Deployment description](eap74-rhel8-payg/src/main/resources/marketing-artifacts/partner-center.html)

#### JBoss EAP Cluster on VM Scale Sets(PAYG/BYOS)

[Deployment description](eap74-rhel8-payg-vmss/src/main/resources/marketing-artifacts/partner-center.html)

#### JBoss EAP Cluster on VMs(PAYG/BYOS)

[Deployment description](eap74-rhel8-payg-multivm/src/main/resources/marketing-artifacts/partner-center.html)

### Red Hat JBoss EAP on ARO

[Deployment description](eap-aro/src/main/resources/marketing-artifacts/partner-center.html)

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
.\Deploy-AzTemplate.ps1 -ArtifactStagingDirectory .\eap74-rhel8-payg-multivm -ResourceGroupLocation southeastasia -dev -UploadArtifacts
```

## Validating templates

You can use the [Azure Resource Manager Template Toolkit](https://github.com/Azure/arm-ttk) (`arm-ttk`) to validate the templates. You'll need to have [installed Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (for Mac, Windows, Linux). 

1. Donwload the latest TTK from https://aka.ms/arm-ttk-latest
2. Extract it somewhere
3. Move into the `ttk/arm-ttk` directory (e.g. `cd ttk/arm-ttk`)
4. Run Powershell
5. Within Powershell, execute `Import-Module ./arm-ttk.psd1`
6. To validate one of the offers, run `Test-AzTemplate -TemplatePath [PATH TO OFFER BASE DIRECTORY]`

The [GitHub Actions file in this repo](.github/workflows/validate-templates.yaml) does the same on pull requests or pushes.

## Merge policy

* Squash and merge
