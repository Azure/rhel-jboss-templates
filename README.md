[![Validate Deployment Templates](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml/badge.svg?branch=master)](https://github.com/Azure/rhel-jboss-templates/actions/workflows/validate-templates.yaml)

This repo contains JBoss EAP Marketplace templates for use on Azure Marketplace. Each subdirectory corresponds to one of the offered plans.

## Deployment Description

There are three different types of EAP on VM offers based on their outcomes.

| Type   | Offer                                         | Description                                                                                                                                                                                                 |
|--------|-----------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| on VMs | JBoss EAP standalone on RHEL VM(PAYG/BYOS)    | [Deployment description](https://htmlpreview.github.io/?https://github.com/azure-javaee/rhel-jboss-templates/blob/main/eap74-rhel8-payg/src/main/resources/marketing-artifacts/partner-center.html)         |
| on VMs | JBoss EAP Cluster on VM Scale Sets(PAYG/BYOS) | [Deployment description](https://htmlpreview.github.io/?https://github.com/azure-javaee/rhel-jboss-templates/blob/main/eap74-rhel8-payg-vmss/src/main/resources/marketing-artifacts/partner-center.html)    |
| on VMs | JBoss EAP Cluster on VMs(PAYG/BYOS)           | [Deployment description](https://htmlpreview.github.io/?https://github.com/azure-javaee/rhel-jboss-templates/blob/main/eap74-rhel8-payg-multivm/src/main/resources/marketing-artifacts/partner-center.html) |
| on ARO | JBoss EAP on ARO                              | [Deployment description](https://htmlpreview.github.io/?https://github.com/azure-javaee/rhel-jboss-templates/blob/main/eap-aro/src/main/resources/marketing-artifacts/partner-center.html)                  |

## Local Build Setup and Requirements
This project utilizes [GitHub Packages](https://github.com/features/packages) for hosting and retrieving some dependencies. To ensure you can smoothly run and build the project in your local environment, specific configuration settings are required.

GitHub Packages requires authentication to download or publish packages. Therefore, you need to configure your Maven `settings.xml` file to authenticate using your GitHub credentials. The primary reason for this is that GitHub Packages does not support anonymous access, even for public packages.

Please follow these steps:

1. Create a Personal Access Token (PAT)
   - Go to [Personal access tokens](https://github.com/settings/tokens).
   - Click on Generate new token.
   - Give your token a descriptive name, set the expiration as needed, and select the scopes (read:packages, write:packages).
   - Click Generate token and make sure to copy the token.
   
2. Configure Maven Settings
   - Locate or create the settings.xml file in your .m2 directory(~/.m2/settings.xml).
   - Add the GitHub Package Registry server configuration with your username and the PAT you just created. It should look something like this:
      ```xml
       <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 
                              https://maven.apache.org/xsd/settings-1.2.0.xsd">
        
      <!-- other settings
      ...
      -->
     
        <servers>
          <server>
            <id>github</id>
            <username>YOUR_GITHUB_USERNAME</username>
            <password>YOUR_PERSONAL_ACCESS_TOKEN</password>
          </server>
        </servers>
     
      <!-- other settings
      ...
      -->
     
       </settings>
      ```

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
