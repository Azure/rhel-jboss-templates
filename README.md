[![Validate Deployment Templates](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml/badge.svg?branch=master)](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml)

This repo contains JBoss EAP Marketplace templates for use on Azure Marketplace. Each subdirectory corresponds to one of the offered plans.

## Deployment Description
Below sections describe the outcomes of each Azure marketplace offer.
### Red Hat JBoss EAP on VMs
There are three different types of EAP on VM offers based on their outcomes.
#### JBoss EAP standalone on RHEL VM(PAYG/BYOS)
This offer provisions:
* Network resources
    * An virtual network and a subnet if users choose to create a new virtual network. Users can also bring their own.
    * A network security group if users choose to create a new virtual network.
    * A network interface with only a private IP address.
* Computing resources
    * A RHEL 8.6 VM with the following settings based on user's choice:
        * VM size
        * VM administrator authentication type and the related credential.
* Storage resources
    * A storage account if users choose to enable boot diagnostics and create a new storage account.
* Software components
    * A JBoss EAP 7.4 standalone instance with user provided admin credentials.
    * OpenJDK 8, 11, 17 are supported choices of JDKs.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.
#### JBoss EAP Cluster on VM Scale Sets(PAYG/BYOS)
This offer provisions:
* Network resources
    * An virtual network and a subnet if users choose to create a new virtual network. Users can also bring their own.
    * A network security group if users choose to create a new virtual network.
    * A public IP address for application gateway if users choose to enable.
* Computing resources
    * A virtual machine scale sets(VMSS) based on RHEL 8.6 image with the following settings based on user's choice:
        * Number of instances
        * VM size
        * VM administrator authentication type and the related credential.
    * An OS disk attached to the VM.
* Load balancing resources
    * An application gateway if users choose to enable.
* Storage resources
    * A storage account if users choose to enable boot diagnostics and create a new storage account.
    * A storage account for setting up Azure ping protocol for JGroups usage.
    * A key vault for self-signed certificate storing if users choose to enable application gateway.
* Managed identity(to be removed)
    * An user assigned managed identity for running deployment scripts on created VMSS.
* Software components
    * JBoss EAP 7.4 standalone instances with user provided admin credentials.
    * OpenJDK 8, 11, 17 are supported choices of JDKs.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.
#### JBoss EAP Cluster on VMs(PAYG/BYOS)
This offer provisions:
* Network resources
    * An virtual network and a subnet if users choose to create a new virtual network. Users can also bring their own.
    * A network security group if users choose to create a new virtual network.
    * A public IP address for application gateway if users choose to enable.
    * A number of network interface for virtual machines based on user's choice of "Number of instances".
    * A number of public IP addresses for virtual machines based on user's choice of "Number of instances".
* Computing resources
    * A number of virtual machine based on RHEL 8.6 image with the following settings based on user's choice:
        * Number of instances
        * VM size
        * VM administrator authentication type and the related credential.
    * A number of OS disks attached to the VM.
    * An availability set for virtual machines(to be removed).
* Load balancing resources
    * An application gateway if users choose to enable.
* Storage resources
    * A storage account if users choose to enable boot diagnostics and create a new storage account.
    * A storage account for setting up Azure ping protocol for JGroups usage.
    * A storage account for configuration files sharing between virtual machines.
    * A key vault for self-signed certificate storing if users choose to enable application gateway.
* Software components
    * JBoss EAP 7.4 standalone/managed domain instances with user provided admin credentials.
    * OpenJDK 8, 11, 17 are supported choices of JDKs.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.
### Red Hat JBoss EAP on ARO
This offer provisions:
* Network resources
    * An virtual network and a subnet.
* Computing resources
    * An Azure Red Hat OpenShift.
* Managed identity(to be removed)
    * An user assigned managed identity for running deployment scripts on created ARO.
* Software components
    * The latest version of JBoss EAP Operator.
    * Source-to-Image application deployment if users choose to enable. The deployment environment is based on JDK 11 and EAP7.4.

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
