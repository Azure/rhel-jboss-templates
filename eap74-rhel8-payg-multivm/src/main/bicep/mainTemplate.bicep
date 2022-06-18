@description('User name for the Virtual Machine')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
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

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_DS2_v2'

@description('Number of VMs to deploy')
param numberOfInstances int = 2

@description('Number of server instances per host')
param numberOfServerInstances int = 2

@description('Enable Load Balancer')
@allowed([
  'enable'
  'disable'
])
param enableLoadBalancer string = 'enable'

@description('Managed domain mode or standalone mode')
param operatingMode string = 'managed-domain'

@description('Name of the availability set')
param asName string = 'jbosseap-as'

@description('Name of the virtual machines')
param vmName string = 'jbosseap-byos-server'

@allowed([
  'on'
  'off'
])
param bootDiagnostics string = 'on'

@description('Name of the existing or new VNET')
param virtualNetworkName string = 'jbosseap-vnet'

@description('Specify whether to create a new or existing virtual network for the VM.')
@allowed([
  'new'
  'existing'
])
param virtualNetworkNewOrExisting string = 'new'

@description('Resource group of Virtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Address prefix of the VNET.')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the existing or new Subnet')
param subnetName string = 'jbosseap-server-subnet'

@description('Address prefix of the subnet')
param subnetPrefix string = '10.0.0.0/24'

@description('Specify whether to create a new or use an existing Boot Diagnostics Storage Account.')
@allowed([
  'New'
  'Existing'
])
param bootStorageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'boot${uniqueString(resourceGroup().id)}'

@description('Name of the resource group for the existing storage account')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Select the Replication Strategy for the Storage account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param bootStorageReplication string = 'Standard_LRS'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object

var name_managedDomain = 'managed-domain'
var name_fileshare = 'jbossshare'
var containerName = 'eapblobcontainer'
var eapStorageAccountName = 'jbosstrg${uniqueString(resourceGroup().id)}'
var eapstorageReplication = 'Standard_LRS'
var loadBalancersName_var = 'jbosseap-lb'
var vmName_var = vmName
var asName_var = asName
var skuName = 'Aligned'
var nicName_var = 'jbosseap-server-nic'
var privateSaEndpointName_var = 'saep${uniqueString(resourceGroup().id)}'
var bootDiagnosticsCheck = ((bootStorageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var bootStorageName_var = ((bootStorageNewOrExisting == 'Existing') ? existingStorageAccount : bootStorageAccountName)
var backendPoolName = 'jbosseap-server'
var frontendName = 'LoadBalancerFrontEnd'
var healthProbeEAP = 'eap-jboss-health'
var healthProbeAdmin = 'eap-admin-health'
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
var scriptFolder = 'scripts'
var fileFolder = 'bin'
var fileToBeDownloaded = 'eap-session-replication.war'
var scriptArgs = '-a "${uri(artifactsLocation, '.')}" -t "${empty(artifactsLocationSasToken) ? '?' : 'artifactsLocationSasToken'}" -p ${fileFolder} -f ${fileToBeDownloaded} -s ${scriptFolder}'
var const_arguments = '${scriptArgs} ${jbossEAPUserName} ${base64(jbossEAPPassword)} ${rhsmUserName} ${base64(rhsmPassword)} ${rhsmPoolEAP} ${eapStorageAccountName} ${containerName} ${resourceGroup().name} ${numberOfInstances} ${vmName_var} ${numberOfServerInstances} ${operatingMode} ${virtualNetworkNewOrExisting}'
var const_scriptLocation = uri(artifactsLocation, 'scripts/')
var const_setupJBossScript = 'jbosseap-setup-redhat.sh'
var const_setupDomainMasterScript = 'jbosseap-setup-master.sh'
var const_setupDomainSlaveScript = 'jbosseap-setup-slave.sh'
var const_setupDomainStandaloneScript = 'jbosseap-setup-standalone.sh'
var const_enableLoadBalancer = bool(enableLoadBalancer == 'enable')

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-1879addb-1fa9-4225-8bd2-6d0a1ffc5dc0-partnercenter'
  params: {}
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@2021-04-01' = if (bootDiagnosticsCheck) {
  name: bootStorageName_var
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
}

resource eapStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: eapStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: eapstorageReplication
    tier: 'Standard'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: false
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
}

resource eapStorageAccountNameContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: '${eapStorageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    eapStorageAccount
  ]
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-08-01' = if (operatingMode == name_managedDomain) {
  name: '${eapStorageAccount.name}/default/${name_fileshare}'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
  dependsOn: [
    eapStorageAccount
  ]
}

resource symbolicname 'Microsoft.Network/privateEndpoints@2021-05-01' = if (operatingMode == name_managedDomain) {
  name: privateSaEndpointName_var
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateSaEndpointName_var
        properties: {
          privateLinkServiceId:resourceId('Microsoft.Storage/storageAccounts/', eapStorageAccountName)
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
    }
  }
  dependsOn: [
    eapStorageAccount
  ]
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
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

resource nicName 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, numberOfInstances): {
  name: concat(nicName_var, i)
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
          loadBalancerBackendAddressPools: const_enableLoadBalancer ? [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancersName_var, backendPoolName)
            }
          ] : json('null')
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkName_resource
    loadBalancersName
  ]
}]

resource vmName_resource 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, numberOfInstances): {
  name: concat(vmName_var, i)
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  properties: {
    availabilitySet: {
      id: asName_resource.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', concat(nicName_var, i))
        }
      ]
    }
    osProfile: {
      computerName: concat(vmName_var, i)
      adminUsername: adminUsername
      adminPassword: adminPasswordOrSSHKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
      }
      imageReference: imageReference
    }
    diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "${reference(resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts/', bootStorageName_var), '2021-06-01').primaryEndpoints.blob}"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
  }
  dependsOn: [
    nicName
    asName_resource
    bootStorageName
    virtualNetworkName_resource
    eapStorageAccount
  ]
}]

resource jbossEAPSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'jbosseap-setup'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.15.0'
    arguments: const_arguments
    primaryScriptUri: uri(const_scriptLocation, '${const_setupJBossScript}${artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_setupDomainMasterScript}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_setupDomainSlaveScript}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_setupDomainStandaloneScript}${artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    vmName_resource
    eapStorageAccount
  ]
}

// resource vmName_jbosseap_setup_extension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, numberOfInstances): {
//   name: '${vmName_var}${i}/jbosseap-setup-extension-${i}'
//   location: location
//   tags: {
//     QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
//   }
//   properties: {
//     publisher: 'Microsoft.Azure.Extensions'
//     type: 'CustomScript'
//     typeHandlerVersion: '2.0'
//     autoUpgradeMinorVersion: true
//     settings: {
//       fileUris: [
//         uri(artifactsLocation, 'scripts/jbosseap-setup-redhat.sh${artifactsLocationSasToken}')
//       ]
//     }
//     protectedSettings: {
//       commandToExecute: 'sh jbosseap-setup-redhat.sh ${scriptArgs} \'${jbossEAPUserName}\' \'${jbossEAPPassword}\' \'${rhsmUserName}\' \'${rhsmPassword}\' \'${rhsmPoolEAP}\' \'${eapStorageAccountName_var}\' \'${containerName}\' \'${base64(listKeys(eapStorageAccountName.id, '2021-04-01').keys[0].value)}\''
//     }
//   }
//   dependsOn: [
//     resourceId('Microsoft.Compute/virtualMachines', concat(vmName_var, i))
//   ]
// }]

resource loadBalancersName 'Microsoft.Network/loadBalancers@2020-11-01' = if (const_enableLoadBalancer) {
  name: loadBalancersName_var
  location: location
  sku: {
    name: 'Basic'
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    loadBalancingRules: [
      {
        name: '${loadBalancersName_var}-rule1'
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
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancersName_var, healthProbeEAP)
          }
        }
      }
      {
        name: '${loadBalancersName_var}-rule2'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancersName_var, frontendName)
          }
          frontendPort: 9990
          backendPort: 9990
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          protocol: 'Tcp'
          enableTcpReset: false
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancersName_var, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancersName_var, healthProbeAdmin)
          }
        }
      }
    ]
    probes: [
      {
        name: healthProbeEAP
        properties: {
          protocol: 'Tcp'
          port: 8080
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
      {
        name: healthProbeAdmin
        properties: {
          protocol: 'Tcp'
          port: 9990
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

resource asName_resource 'Microsoft.Compute/availabilitySets@2021-03-01' = {
  name: asName_var
  location: location
  sku: {
    name: skuName
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  properties: {
    platformUpdateDomainCount: 2
    platformFaultDomainCount: 2
  }
}

output appURL string = const_enableLoadBalancer ? (uri('http://${loadBalancersName.properties.frontendIPConfigurations[0].properties.privateIPAddress}', 'eap-session-replication/')) : ''
