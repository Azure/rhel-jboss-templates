[![Validate Deployment Templates](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml/badge.svg?branch=master)](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml)

This repo contains JBoss EAP Marketplace templates for use on Azure Marketplace. Each subdirectory corresponds to one of the offered plans.

## Deployment Description

### Red Hat JBoss EAP on VMs

There are three different types of EAP on VM offers based on their outcomes.

#### JBoss EAP standalone on RHEL VM(PAYG/BYOS)

This offer provisions a single Red Hat JBoss EAP server with JBoss EAP management console. All supporting Azure resources are automatically provisioned.

* Computing resources
    * A RHEL 8.6 VM with the following settings based on user's choice:
        * Choice of VM size
* Network resources
    * A virtual network and a subnet if users choose to create a new virtual network. You can also choose to deploy into a pre-existing virtual network.
    * A network security group if users choose to create a new virtual network.
    * A network interface with a private IP address.
* Key software components
    * A JBoss EAP 7.4 standalone instance with user provided admin credentials. The **EAP_HOME** is **/opt/rh/eap7/root/usr/share/wildfly**.
    * OpenJDK 8, 11, or 17. The **JAVA_HOME** is a subdirectory of **/usr/lib/jvm**, depending on the selected JDK version.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.

#### JBoss EAP Cluster on VM Scale Sets(PAYG/BYOS)

This offer provisions a Red Hat JBoss EAP server, JBoss EAP management console, and an EAP cluster on Azure Virtual Machine Scale Sets. All supporting Azure resources are automatically provisioned.

* Computing resources
    * A virtual machine scale sets(VMSS) based on RHEL 8.6 image with the following settings based on user's choice:
        * Number of instances
        * Choice of VM size
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet if users choose to create a new virtual network. You can also choose to deploy into a pre-existing virtual network.
    * A network security group if users choose to create a new virtual network.
    * A public IP address for application gateway if users choose to enable.
* Load balancing resources
    * An application gateway if users choose to enable.
* Storage resources
    * A storage account if users choose to enable boot diagnostics and create a new storage account.
    * A storage account for setting up Azure ping protocol for JGroups usage.
    * A network interface with a private IP address.
* Key software components
    * A JBoss EAP 7.4 standalone instance with user provided admin credentials. The **EAP_HOME** is **/opt/rh/eap7/root/usr/share/wildfly**.
    * OpenJDK 8, 11, or 17. The **JAVA_HOME** is a subdirectory of **/usr/lib/jvm**, depending on the selected JDK version.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.

#### JBoss EAP Cluster on VMs(PAYG/BYOS)


This offer provisions a Red Hat JBoss EAP server, JBoss EAP management console, and an EAP cluster. All supporting Azure resources are automatically provisioned.

* The offer includes a choice of Red Hat OpenJDK 8, 11, and 17.

* Computing resources
    * VMs with the followings configurations:
      * A VM to run the JBoss EAP management console and an arbitrary number of VMs to run JBoss EAP servers
      * Choice of VM size
    * A number of OS disks attached to the VM.
* Network resources
    * An virtual network and a subnet if users choose to create a new virtual network. Users can also bring their own.
    * A network security group if users choose to create a new virtual network.
    * A public IP address for application gateway if users choose to enable.
    * A number of network interface for virtual machines based on user's choice of "Number of instances".
    * A number of public IP addresses for virtual machines based on user's choice of "Number of instances".
* Load balancing resources
    * An application gateway if users choose to enable.
* Storage resources
    * A storage account for setting up Azure ping protocol for JGroups usage.
    * A storage account for sharing configuration files between virtual machines.
* Key software components
    * A JBoss EAP 7.4 standalone instance with user provided admin credentials. The **EAP_HOME** is **/opt/rh/eap7/root/usr/share/wildfly**.
    * OpenJDK 8, 11, or 17. The **JAVA_HOME** is a subdirectory of **/usr/lib/jvm**, depending on the selected JDK version.
    * This JBoss EAP host can be registered to an existing Red Hat Satellite server for management.

### Red Hat JBoss EAP on ARO

[Partner center verbiage](eap-aro/src/main/resources/marketing-artifacts/partner-center.html)

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
