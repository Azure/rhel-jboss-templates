@description('User name for the Virtual Machine')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
@minLength(12)
@secure()
param adminPasswordOrSSHKey string

@description('Location for all resources')
param location string = resourceGroup().location

@description('User name for the JBoss EAP Manager')
param jbossEAPUserName string

@description('Password for the JBoss EAP Manager')
@minLength(12)
@secure()
param jbossEAPPassword string

@description('User name for Red Hat subscription Manager')
param rhsmUserName string

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
param rhsmPoolEAP string

@allowed([
  'on'
  'off'
])
param bootDiagnostics string = 'on'

@description('Specify whether to create a new or use an existing Storage Account.')
@allowed([
  'New'
  'Existing'
])
param bootStorageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'jbboot${uniqueString(resourceGroup().id)}'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Name of the resource group for the existing storage account')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Select the Replication Strategy for the Storage account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param bootStorageReplication string = 'Standard_LRS'

@description('Specify whether to create a new or existing virtual network for the VM.')
@allowed([
  'new'
  'existing'
])
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the existing or new VNET')
param virtualNetworkName string = 'jbosseap-vnet'

@description('Resource group of VIrtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Address prefix of the VNET.')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the existing or new Subnet')
param subnetName string = 'jbosseap-server-subnet'

@description('Address prefix of the subnet')
param subnetPrefix string = '10.0.0.0/24'

@description('String used as a base for naming resources (9 characters or less). A hash is prepended to this string for some resources, and resource-specific information is appended')
@maxLength(9)
param vmssName string

@description('Number of VM instances (100 or less)')
@minValue(2)
@maxValue(100)
param instanceCount int = 2

@description('The size of the Virtual Machine scale set')
param vmSize string = 'Standard_DS2_v2'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated')
@secure()
param artifactsLocationSasToken string = ''

var containerName = 'eapblobcontainer'
var eapStorageAccountName_var = 'jbosstrg${uniqueString(resourceGroup().id)}'
var eapstorageReplication = 'Standard_LRS'
var loadBalancersName_var = 'jbosseap-lb'
var vmssInstanceName_var = 'jbosseap-server${vmssName}'
var nicName = 'jbosseap-server-nic'
var bootDiagnosticsCheck = ((bootStorageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var bootStorageName_var = ((bootStorageNewOrExisting == 'Existing') ? existingStorageAccount : bootStorageAccountName)
var backendPoolName = 'jbosseap-server'
var frontendName = 'LoadBalancerFrontEnd'
var natRuleName = 'adminconsolerule'
var natStartPort = 9000
var natEndPort = 9120
var adminBackendPort = 9990
var healthProbe = 'eap-lb-health'
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrSSHKey
      }
    ]
  }
}
var imageReference = {
  publisher: 'RedHat'
  offer: 'RHEL'
  sku: '8_4'
  version: 'latest'
}
var scriptFolder = 'bin'
var fileToBeDownloaded = 'eap-session-replication.war'
var scriptArgs = '-a \'${uri(artifactsLocation, '.')}\' -t "${artifactsLocationSasToken}" -p ${scriptFolder} -f ${fileToBeDownloaded}'

resource bootStorageName 'Microsoft.Storage/storageAccounts@2021-04-01' = if (bootDiagnosticsCheck) {
  name: bootStorageName_var
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

resource eapStorageAccountName 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: eapStorageAccountName_var
  location: location
  sku: {
    name: eapstorageReplication
  }
  kind: 'Storage'
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

resource eapStorageAccountName_default_containerName 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: '${eapStorageAccountName_var}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    eapStorageAccountName
  ]
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

resource vmssInstanceName 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: vmssInstanceName_var
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: vmssInstanceName_var
        adminUsername: adminUsername
        adminPassword: adminPasswordOrSSHKey
        linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancersName_var, backendPoolName)
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', loadBalancersName_var, natRuleName)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "${reference(resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts/', bootStorageName_var), '2021-06-01').primaryEndpoints.blob}"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
      extensionProfile: {
        extensions: [
          {
            name: 'jbosseap-setup-extension'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  uri(artifactsLocation, 'scripts/jbosseap-setup-redhat.sh${artifactsLocationSasToken}')
                ]
              }
              protectedSettings: {
                commandToExecute: 'sh jbosseap-setup-redhat.sh ${scriptArgs} \'${jbossEAPUserName}\' \'${base64(jbossEAPPassword)}\' \'${rhsmUserName}\' \'${base64(rhsmPassword)}\' \'${rhsmPoolEAP}\' \'${eapStorageAccountName_var}\' \'${containerName}\' \'${base64(listKeys(eapStorageAccountName.id, '2021-06-01').keys[0].value)}\''
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    loadBalancersName
    bootStorageName
    virtualNetworkName_resource

  ]
}

resource loadBalancersName 'Microsoft.Network/loadBalancers@2020-11-01' = {
  name: loadBalancersName_var
  location: location
  sku: {
    name: 'Basic'
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    inboundNatPools: [
      {
        name: natRuleName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancersName_var, frontendName)
          }
          protocol: 'Tcp'
          frontendPortRangeStart: natStartPort
          frontendPortRangeEnd: natEndPort
          backendPort: adminBackendPort
        }
      }
    ]
    loadBalancingRules: [
      {
        name: '${loadBalancersName_var}-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancersName_var, frontendName)
          }
          frontendPort: 80
          backendPort: 8080
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          protocol: 'Tcp'
          enableTcpReset: false
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancersName_var, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancersName_var, healthProbe)
          }
        }
      }
    ]
    probes: [
      {
        name: healthProbe
        properties: {
          protocol: 'Tcp'
          port: 8080
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkName_resource
  ]
}

output appURL string = uri('http://${loadBalancersName.properties.frontendIPConfigurations[0].properties.privateIPAddress}', 'eap-session-replication/')
