@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Virtual Machine.')
param vmName string= 'jbosseapVm'

@description('Linux VM user account name')
param adminUsername string = 'jbossuser'

@description('Public IP Name for the VM')
param vmPublicIPAddressName string = 'vmip'

@description('DNS prefix for VM')
param dnsNameforVM string = 'jbossvm${take(uniqueString(utcNow()), 6)}'

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
@secure()
param adminPasswordOrSSHKey string

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_DS2_v2'

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'openjdk17'

@description('Capture serial console outputs and screenshots of the virtual machine running on a host to help diagnose startup issues')
@allowed([
  'off'
  'on'
])
param bootDiagnostics string = 'on'

@description('Determines whether or not a new storage account should be provisioned.')
param storageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the storage account')
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'

@description('Storage account type')
param storageAccountType string = 'Standard_LRS'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Name of the resource group for the existing storage account')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Determines whether or not a new virtual network should be provisioned.')
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the virtual network')
param virtualNetworkName string = 'VirtualNetwork'

@description('Address prefix of the virtual network')
param addressPrefixes array = [
  '10.0.0.0/28'
]

@description('Name of the subnet')
param subnetName string = 'default'

@description('Subnet prefix of the virtual network')
param subnetPrefix string = '10.0.0.0/29'

@description('Name of the resource group for the existing virtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('User name for JBoss EAP Manager')
param jbossEAPUserName string

@description('Password for JBoss EAP Manager')
@secure()
param jbossEAPPassword string

@description('User name for Red Hat subscription Manager')
param rhsmUserName string = newGuid()

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
@minLength(32)
@maxLength(32)
param rhsmPoolEAP string = take(newGuid(), 32)

@description('Red Hat Subscription Manager Pool ID (Should have RHEL entitlement)')
@minLength(32)
@maxLength(32)
param rhsmPoolRHEL string = take(newGuid(), 32)

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated')
@secure()
param artifactsLocationSasToken string = ''

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = newGuid()

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = newGuid()

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = newGuid()

@description('Boolean value indicating, if user wants to enable database connection.')
param enableDB bool = false
@allowed([
  'mssqlserver'
  'postgresql'
  'oracle'
  'mysql'
])
@description('One of the supported database types')
param databaseType string = 'postgresql'
@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceJNDIName string = 'jdbc/contoso'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database:5432/testdb'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@secure()
@description('Password for Database')
param dbPassword string = newGuid()

param guidValue string = take(replace(newGuid(), '-', ''), 6)

var nicName_var = '${uniqueString(resourceGroup().id)}-nic'
var networkSecurityGroupName_var = 'jbosseap-nsg'
var bootDiagnosticsCheck = ((storageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var bootStorageName_var = ((storageNewOrExisting == 'Existing') ? existingStorageAccount : storageAccountName)
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
var name_postDeploymentDsName = format('updateNicPrivateIpStatic{0}', guidValue)
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}

/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-e9412731-57c2-4e6a-9825-061ad30337c0-partnercenter'
  params: {}
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

module byosSingleStartPid './modules/_pids/_pid.bicep' = {
  name: 'byosSingleStartPid'
  params: {
    name: pids.outputs.byosSingleStart
  }
  dependsOn: [
    pids
  ]
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = if (bootDiagnosticsCheck) {
  name: bootStorageName_var
  location: location
  sku: {
    name: storageAccountType
  }
  kind: storageAccountKind
}

resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@${azure.apiVersionForNetworkSecurityGroups}' = {
  name: networkSecurityGroupName_var
  location: location
  properties: {
      securityRules: [
        {
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: 'Internet'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 510
            direction: 'Inbound'
            destinationPortRanges: [
              '80'
              '443'
              '9990'
              '8080'
            ]
          }
          name: 'ALLOW_HTTP_ACCESS'
        }
      ]
    }
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroupName.id
          }
        }
      }
    ]
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = {
  name: nicName_var
  location: location
  properties: {
    networkSecurityGroup: {
      id: networkSecurityGroupName.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets/', virtualNetworkName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkName_resource

  ]
}

resource vmName_resource 'Microsoft.Compute/virtualMachines@${azure.apiVersionForVirtualMachines}' = {
  name: vmName
  location: location
  plan: {
    name: 'rhel-lvm86-gen2'
    publisher: 'redhat'
    product: 'rhel-byos'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrSSHKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      imageReference: {
        publisher: 'redhat'
        offer: 'rhel-byos'
        sku: 'rhel-lvm86-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
      networkInterfaceConfigurations: [
        {
          name: nicName_var
          properties: {
            primary: true
            ipConfigurations: [
              {
                name: 'ipconfig1'
                properties: {
                  privateIPAllocationMethod: 'Dynamic'
                  subnet: {
                    id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                  }
                  publicIPAddressConfiguration: {
                    name: 'vmPublicIpConfig'
                    properties: {
                      publicIPAddress: {
                        id: resourceId('Microsoft.Network/publicIPAddresses', vmPublicIPAddressName)
                      }
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }

    diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "${reference(resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts/', bootStorageName_var), '2021-06-01').primaryEndpoints.blob}"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
  }
  dependsOn: [
    bootStorageName
    networkSecurityGroupName
    vmPublicIP
  ]
}

resource vmPublicIP 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = {
  name: vmPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforVM
    }
  }
}

module dbConnectionStartPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionStartPid'
  params: {
    name: pids.outputs.dbStart
  }
  dependsOn: [
    pids
    vmName_resource
  ]
}

resource vmName_jbosseap_setup_extension 'Microsoft.Compute/virtualMachines/extensions@${azure.apiVersionForVirtualMachineExtensions}' = {
  parent: vmName_resource
  name: 'jbosseap-setup-extension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        uri(artifactsLocation, 'scripts/jbosseap-setup-redhat.sh${artifactsLocationSasToken}')
        uri(artifactsLocation, 'scripts/create-ds-postgresql.sh${artifactsLocationSasToken}')
        uri(artifactsLocation, 'scripts/create-ds-mssqlserver.sh${artifactsLocationSasToken}')
        uri(artifactsLocation, 'scripts/create-ds-oracle.sh${artifactsLocationSasToken}')
        uri(artifactsLocation, 'scripts/create-ds-mysql.sh${artifactsLocationSasToken}')
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh jbosseap-setup-redhat.sh \'${jbossEAPUserName}\' \'${base64(jbossEAPPassword)}\' \'${rhsmUserName}\' \'${base64(rhsmPassword)}\' \'${rhsmPoolEAP}\' \'${rhsmPoolRHEL}\' \'${connectSatellite}\' \'${base64(satelliteActivationKey)}\' \'${base64(satelliteOrgName)}\' \'${satelliteFqdn}\' \'${jdkVersion}\' \'${enableDB}\' \'${databaseType}\' \'${base64(jdbcDataSourceJNDIName)}\' \'${base64(dsConnectionURL)}\' \'${base64(dbUser)}\' \'${base64(dbPassword)}\''
    }
  }
}

module updateNicPrivateIpStatic 'modules/_deployment-scripts/_dsPostDeployment.bicep' = {
  name: name_postDeploymentDsName
  params: {
    name: name_postDeploymentDsName
    location: location
    _artifactsLocation: artifactsLocation
    _artifactsLocationSasToken: artifactsLocationSasToken
    identity: obj_uamiForDeploymentScript
    resourceGroupName: resourceGroup().name
    nicName: nicName_var
  }
  dependsOn: [
    nicName
    uamiDeployment
  ]
}

module dbConnectionEndPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionEndPid'
  params: {
    name: pids.outputs.dbEnd
  }
  dependsOn: [
    pids
    vmName_jbosseap_setup_extension
  ]
}

module byosSingleEndPid './modules/_pids/_pid.bicep' = {
  name: 'byosSingleEndPid'
  params: {
    name: pids.outputs.byosSingleEnd
  }
  dependsOn: [
    dbConnectionEndPid
  ]
}
