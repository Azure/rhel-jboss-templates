param guidValue string = take(replace(newGuid(), '-', ''), 6)

param guidTag string = newGuid()

@description('User name for the Virtual Machine')
param adminUsername string = 'jbossuser'

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

@description('Please enter a Graceful Shutdown Timeout in seconds')
param gracefulShutdownTimeout string

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_DS2_v2'

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'eap8-openjdk17'

@description('Number of VMs to deploy')
param numberOfInstances int = 2

@description('Number of server instances per host')
param numberOfServerInstances int = 1

@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false

@description('Managed domain mode or standalone mode')
@allowed([
  'standalone'
  'managed-domain'
])
param operatingMode string = 'managed-domain'

@description('Name of the availability set')
param asName string = 'jbosseapAs'

@description('Name of the virtual machines')
param vmName string = 'jbosseapVm'

@allowed([
  'on'
  'off'
])
param bootDiagnostics string = 'off'

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

@description('Name of the existing or new Subnet')
param subnetForAppGateway string = 'jboss-appgateway-subnet'

@description('Address prefix of the subnet')
param subnetPrefixForAppGateway string = '10.0.1.0/24'

@description('Specify whether to create a new or use an existing Boot Diagnostics Storage Account.')
@allowed([
  'new'
  'existing'
])
param bootStorageNewOrExisting string = 'new'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'boot'

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

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = newGuid()

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = newGuid()

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = newGuid()

@description('Price tier for Key Vault.')
param keyVaultSku string = 'Standard'

@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'jbossgw'

@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data for Appliation Gateway frontend TLS/SSL.')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'

@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false

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
@description('Enable passwordless datasource connection.')
param enablePswlessConnection bool = false
@description('Managed identity that has access to database')
param dbIdentity object = {}
@description('${label.tagsLabel}')
param tagsByResource object = {}

var name_managedDomain = 'managed-domain'
var name_fileshare = 'jbossshare'
var skuName = 'Aligned'
var eapstorageReplication = 'Standard_LRS'

var uamiId= enablePswlessConnection ? items(dbIdentity.userAssignedIdentities)[0].key: 'NA'
var uamiClientId = enablePswlessConnection ? reference(uamiId, '${azure.apiVersionForIdentity}', 'full').properties.clientId : 'NA'
var containerName = 'eapblobcontainer-${guidValue}'
var eapStorageAccountName = 'jbosstrg${guidValue}'
var vmName_var = '${vmName}-${guidValue}'
var asName_var = '${asName}-${guidValue}'
var nicName_var = 'jbosseap-server-nic-${guidValue}'
var privateSaEndpointName_var = 'saep-${guidValue}'
var virtualNetworkName_var = virtualNetworkNewOrExisting != 'new' ? virtualNetworkName : '${virtualNetworkName}-${guidValue}'
var bootStorageName_var = (bootStorageNewOrExisting == 'existing') ? existingStorageAccount : '${bootStorageAccountName}${guidValue}'
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
var name_vmAcceptTerms = format('vmAcceptTerms{0}', guidValue)
var const_newVNet = (virtualNetworkNewOrExisting == 'new') ? true : false

var imageReference = {
  publisher: 'RedHat'
  offer: 'rh-jboss-eap'
  sku: (jdkVersion == 'eap74-openjdk8') ? 'rh-jboss-eap74-jdk8-rhel8' : /*
     */(jdkVersion == 'eap74-openjdk11') ? 'rh-jboss-eap74-jdk11-rhel8' : /*
     */(jdkVersion == 'eap74-openjdk17') ? 'rh-jboss-eap74-jdk17-rhel8' : /*
     */(jdkVersion == 'eap8-openjdk11') ? 'rh-jboss-eap8-jdk11-rhel9' : /*
     */(jdkVersion == 'eap8-openjdk17') ? 'rh-jboss-eap8-jdk17-rhel9' :  null
  version: 'latest'
}

var name_failFastDsName = format('failFast-{0}', guidValue)
var name_jbossEAPDsName = 'jbosseap-setup-${guidValue}'
var name_postDeploymentDsName = format('postdeploymentds{0}', guidValue)
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}
var name_keyVaultName = take('jboss-kv-${guidValue}', 24)
var name_dnsNameforApplicationGateway = '${dnsNameforApplicationGateway}-${guidValue}'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}', 63)
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var name_appgwFrontendSSLCertName = 'appGatewaySslCert-${guidValue}'
var name_appGateway = 'appgw-${guidValue}'
var property_subnet_with_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
  {
    // Assume it is acceptable to create a subnet for the App Gateway, even if the user
    // has not requested an App Gateway.  In support of this assumption we can note: the user may want an App 
    // Gateway after deployment.
    name: subnetForAppGateway
    properties: {
      addressPrefix: subnetPrefixForAppGateway
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]
var property_subnet_without_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
    }
  }
]
var name_publicIPAddress = '-pubIp'
var name_adminVmName = '-adminVM'
var dnsNameforAdminVm = 'jboss-admin${guidValue}'
var dnsNameforManagedVm = 'jboss-managed${guidValue}'
var name_networkSecurityGroup = 'jboss-nsg-${guidValue}'
var name_appGatewayPublicIPAddress = 'gwip-${guidValue}'

var plan = {
  publisher: 'redhat'
  product: 'rh-jboss-eap'
  name: (jdkVersion == 'eap74-openjdk8') ? 'rh-jboss-eap74-jdk8-rhel8' : /*
      */(jdkVersion == 'eap74-openjdk11') ? 'rh-jboss-eap74-jdk11-rhel8' : /*
      */(jdkVersion == 'eap74-openjdk17') ? 'rh-jboss-eap74-jdk17-rhel8' : /*
      */(jdkVersion == 'eap8-openjdk11') ? 'rh-jboss-eap8-jdk11-rhel9' : /*
      */(jdkVersion == 'eap8-openjdk17') ? 'rh-jboss-eap8-jdk17-rhel9' :  null
}


var _objTagsByResource = {
  '${identifier.applicationGateways}': contains(tagsByResource, '${identifier.applicationGateways}') ? tagsByResource['${identifier.applicationGateways}'] : json('{}')
  '${identifier.availabilitySets}': contains(tagsByResource, '${identifier.availabilitySets}') ? tagsByResource['${identifier.availabilitySets}'] : json('{}')
  '${identifier.privateEndpoints}': contains(tagsByResource, '${identifier.privateEndpoints}') ? tagsByResource['${identifier.privateEndpoints}'] : json('{}')
  '${identifier.vaults}': contains(tagsByResource, '${identifier.vaults}') ? tagsByResource['${identifier.vaults}'] : json('{}')
  '${identifier.virtualMachines}': contains(tagsByResource, '${identifier.virtualMachines}') ? tagsByResource['${identifier.virtualMachines}'] : json('{}')
  '${identifier.virtualNetworks}': contains(tagsByResource, '${identifier.virtualNetworks}') ? tagsByResource['${identifier.virtualNetworks}'] : json('{}')
  '${identifier.networkInterfaces}': contains(tagsByResource, '${identifier.networkInterfaces}') ? tagsByResource['${identifier.networkInterfaces}'] : json('{}')
  '${identifier.networkSecurityGroups}': contains(tagsByResource, '${identifier.networkSecurityGroups}') ? tagsByResource['${identifier.networkSecurityGroups}'] : json('{}')
  '${identifier.publicIPAddresses}': contains(tagsByResource, '${identifier.publicIPAddresses}') ? tagsByResource['${identifier.publicIPAddresses}'] : json('{}')
  '${identifier.storageAccounts}': contains(tagsByResource, '${identifier.storageAccounts}') ? tagsByResource['${identifier.storageAccounts}'] : json('{}')
  '${identifier.userAssignedIdentities}': contains(tagsByResource, '${identifier.userAssignedIdentities}') ? tagsByResource['${identifier.userAssignedIdentities}'] : json('{}')
  '${identifier.deploymentScripts}': contains(tagsByResource, '${identifier.deploymentScripts}') ? tagsByResource['${identifier.deploymentScripts}'] : json('{}')
}
/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization-${guidValue}'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-1879addb-1fa9-4225-8bd2-6d0a1ffc5dc0-partnercenter'
  params: {}
}

module paygMultivmStartPid './modules/_pids/_pid.bicep' = {
  name: 'paygMultivmStartPid-${guidValue}'
  params: {
    name: pids.outputs.paygMultivmStart
  }
  dependsOn: [
    pids
  ]
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment-${guidValue}'
  params: {
    guidValue: guidValue
    location: location
    tagsByResource: _objTagsByResource
  }
}

module failFastDeployment 'modules/_deployment-scripts/_ds-failfast.bicep' = {
  name: name_failFastDsName
  params: {
    guidValue: guidValue
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    identity: obj_uamiForDeploymentScript
    vmSize: vmSize
    numberOfInstances: numberOfInstances
    connectSatellite: connectSatellite
    satelliteFqdn: satelliteFqdn
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
    uamiDeployment
  ]
}

module appgwSecretDeployment 'modules/_azure-resources/_keyvaultForGateway.bicep' = if (enableAppGWIngress) {
  name: 'appgateway-certificates-secrets-deployment-${guidValue}'
  params: {
    guidValue: guidValue
    identity: obj_uamiForDeploymentScript
    location: location
    sku: keyVaultSku
    subjectName: format('CN={0}', const_azureSubjectName)
    keyVaultName: name_keyVaultName
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
    failFastDeployment
  ]
}

// Get existing VNET.
resource existingVnet 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet) {
  name: virtualNetworkName_var
  scope: resourceGroup(virtualNetworkResourceGroupName)
}

// Get existing subnet for App Gateway.
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet) {
  name: subnetForAppGateway
  parent: existingVnet
}

// Get existing subnet for VMs.
resource existingVmSubnet 'Microsoft.Network/virtualNetworks/subnets@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet) {
  name: subnetName
  parent: existingVnet
}

module appgwDeployment 'modules/_appgateway.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment-${guidValue}'
  params: {
    guidValue: guidValue
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: name_dnsNameforApplicationGateway
    gatewayPublicIPAddressName: name_appGatewayPublicIPAddress
    gatewaySubnetId: virtualNetworkNewOrExisting == 'new' ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnetForAppGateway) : existingSubnet.id
    gatewaySslCertName: name_appgwFrontendSSLCertName
    location: location
    sslCertDataSecretName: (enableAppGWIngress ? appgwSecretDeployment.outputs.sslCertDataSecretName : keyVaultSSLCertDataSecretName)
    _pidAppgwStart: pids.outputs.appgwStart
    _pidAppgwEnd: pids.outputs.appgwEnd
    keyVaultName: name_keyVaultName
    enableCookieBasedAffinity: enableCookieBasedAffinity
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
    appgwSecretDeployment
    pids
    virtualNetworkName_resource
  ]
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = if ((bootStorageNewOrExisting == 'new') && (bootDiagnostics == 'on')) {
  name: bootStorageName_var
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: union(_objTagsByResource['${identifier.storageAccounts}'], {
      'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
    })
  dependsOn: [
    failFastDeployment
  ]
}

resource eapStorageAccount 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = {
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
  tags: union(_objTagsByResource['${identifier.storageAccounts}'], {
        'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
      })
  dependsOn: [
    failFastDeployment
  ]
}

resource eapStorageAccountNameContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@${azure.apiVersionForStorageBlobService}' = {
  name: '${eapStorageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    failFastDeployment
  ]
  tags: _objTagsByResource['${identifier.storageAccounts}']
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@${azure.apiVersionForStorageFileService}' = if (operatingMode == name_managedDomain) {
  name: '${eapStorageAccount.name}/default/${name_fileshare}'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
  tags: _objTagsByResource['${identifier.storageAccounts}']
}

resource symbolicname 'Microsoft.Network/privateEndpoints@${azure.apiVersionForPrivateEndpoint}' = if (operatingMode == name_managedDomain) {
  name: privateSaEndpointName_var
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateSaEndpointName_var
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts/', eapStorageAccountName)
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnetName)
    }
  }
  dependsOn: [
    eapStorageAccount
  ]
  tags: _objTagsByResource['${identifier.privateEndpoints}']
}

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@${azure.apiVersionForNetworkSecurityGroups}' = if (enableAppGWIngress && virtualNetworkNewOrExisting == 'new') {
  name: name_networkSecurityGroup
  location: location
  properties: {
    securityRules: [
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
        name: 'ALLOW_APPGW'
      }
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
          ]
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
  tags: _objTagsByResource['${identifier.networkSecurityGroups}']
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName_var
  location: location
  tags: union(_objTagsByResource['${identifier.virtualNetworks}'], {
        'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
      })
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: enableAppGWIngress ? property_subnet_with_app_gateway : property_subnet_without_app_gateway
  }
}

module baseImageSelected './modules/_pids/_empty.bicep' = {
  name:(jdkVersion == 'eap74-openjdk8') ? '${azure.guid.eap-rhel-payg-multivm.rh-jboss-eap74-jdk8-rhel8}' : /*
       */(jdkVersion == 'eap74-openjdk11') ? '${azure.guid.eap-rhel-payg-multivm.rh-jboss-eap74-jdk11-rhel8}' : /*
       */(jdkVersion == 'eap74-openjdk17') ? '${azure.guid.eap-rhel-payg-multivm.rh-jboss-eap74-jdk17-rhel8}' : /*
       */(jdkVersion == 'eap8-openjdk11') ? '${azure.guid.eap-rhel-payg-multivm.rh-jboss-eap8-jdk11-rhel9}' : /*
       */(jdkVersion == 'eap8-openjdk17') ? '${azure.guid.eap-rhel-payg-multivm.rh-jboss-eap8-jdk17-rhel9}' : /*
       */'eap-rhel-payg.null'
    params: {}
}

resource publicIp 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = [for i in range(0, numberOfInstances): if (enableAppGWIngress) {
  name: (operatingMode == name_managedDomain) ? ((i == 0) ? '${vmName_var}${name_adminVmName}${name_publicIPAddress}' : '${vmName_var}${i}${name_publicIPAddress}') :'${vmName_var}${i}${name_publicIPAddress}'
  sku: {
    name: 'Standard'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: (operatingMode == name_managedDomain) ? ((i == 0) ? '${dnsNameforAdminVm}' : '${dnsNameforManagedVm}${i}') : '${dnsNameforManagedVm}${i}'
    }
  }
  tags: !const_newVNet ? union(_objTagsByResource['${identifier.publicIPAddresses}'], {
    '${guidTag}': ''
  }) : _objTagsByResource['${identifier.publicIPAddresses}']
}]

resource nicName 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = [for i in range(0, numberOfInstances): {
  name: '${nicName_var}${i}'
  location: location
  tags: union(_objTagsByResource['${identifier.networkInterfaces}'], {
        'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
      })
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: const_newVNet ? resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnetName) : existingVmSubnet.id
          }
          applicationGatewayBackendAddressPools: enableAppGWIngress ? ((operatingMode == name_managedDomain) ? ((i != 0) ? [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, 'managedNodeBackendPool')
            }
          ] : null) : [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, 'managedNodeBackendPool')
            }
          ]) : null
          publicIPAddress: enableAppGWIngress ? {
            id: (operatingMode == name_managedDomain) ? ((i == 0) ? resourceId('Microsoft.Network/publicIPAddresses', '${vmName_var}${name_adminVmName}${name_publicIPAddress}') : resourceId('Microsoft.Network/publicIPAddresses', '${vmName_var}${i}${name_publicIPAddress}')) : resourceId('Microsoft.Network/publicIPAddresses', '${vmName_var}${i}${name_publicIPAddress}')
          } : null
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkName_resource
    appgwDeployment
    publicIp
    existingVmSubnet
  ]
}]

module vmAcceptTerms 'modules/_deployment-scripts/_dsVmAcceptTerms.bicep' = {
  name: name_vmAcceptTerms
  params: {
    name: name_vmAcceptTerms
    location: location
    _artifactsLocation: artifactsLocation
    _artifactsLocationSasToken: artifactsLocationSasToken
    identity: obj_uamiForDeploymentScript
    plan: plan
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
    nicName
    uamiDeployment
  ]
}

resource vmName_resource 'Microsoft.Compute/virtualMachines@${azure.apiVersionForVirtualMachines}' = [for i in range(0, numberOfInstances): {
  name: (operatingMode == name_managedDomain) ? (i == 0 ? '${vmName_var}${name_adminVmName}' : '${vmName_var}${i}') : '${vmName_var}${i}'
  location: location
  identity: enablePswlessConnection ? dbIdentity : null
  tags: union(_objTagsByResource['${identifier.virtualMachines}'], {
        'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
      })
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
          id: resourceId('Microsoft.Network/networkInterfaces', '${nicName_var}${i}')
        }
      ]
    }
    osProfile: {
      computerName: (operatingMode == name_managedDomain) ? (i == 0 ? '${vmName_var}${name_adminVmName}' : '${vmName_var}${i}') : '${vmName_var}${i}'
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
  plan: plan
  dependsOn: [
    nicName
    bootStorageName
    virtualNetworkName_resource
    eapStorageAccount
  ]
}]

module dbConnectionStartPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionStartPid-${guidValue}'
  params: {
    name: pids.outputs.dbStart
  }
  dependsOn: [
    pids
    vmName_resource
    eapStorageAccount
  ]
}

module jbossEAPDeployment 'modules/_deployment-scripts/_ds-jbossEAPSetup.bicep' = {
  name: name_jbossEAPDsName
  params: {
    guidValue: guidValue
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    identity: obj_uamiForDeploymentScript
    jbossEAPUserName: jbossEAPUserName
    jbossEAPPassword: jbossEAPPassword
    eapStorageAccountName: eapStorageAccountName
    containerName: containerName
    numberOfInstances: numberOfInstances
    adminVmName: '${vmName_var}${name_adminVmName}'
    vmName: vmName_var
    numberOfServerInstances: numberOfServerInstances
    operatingMode: operatingMode
    virtualNetworkNewOrExisting: virtualNetworkNewOrExisting
    connectSatellite: connectSatellite
    satelliteActivationKey: satelliteActivationKey
    satelliteOrgName: satelliteOrgName
    satelliteFqdn: satelliteFqdn
    jdkVersion: jdkVersion
    nicName: nicName_var
    enableDB: enableDB
    databaseType: databaseType
    jdbcDataSourceJNDIName: jdbcDataSourceJNDIName
    dsConnectionURL: dsConnectionURL
    dbUser: dbUser
    dbPassword: dbPassword
    gracefulShutdownTimeout: gracefulShutdownTimeout
    enablePswlessConnection: enablePswlessConnection
    uamiClientId: uamiClientId
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
    vmName_resource
    eapStorageAccount
  ]
}

module postDeployment 'modules/_deployment-scripts/_dsPostDeployment.bicep' = if (!const_newVNet) {
  name: name_postDeploymentDsName
  params: {
    name: name_postDeploymentDsName
    location: location
    _artifactsLocation: artifactsLocation
    _artifactsLocationSasToken: artifactsLocationSasToken
    identity: obj_uamiForDeploymentScript
    resourceGroupName: resourceGroup().name
    tagsByResource: _objTagsByResource
    guidTag: guidTag
  }
  dependsOn: [
    jbossEAPDeployment
    uamiDeployment
  ]
}

module dbConnectionEndPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionEndPid-${guidValue}'
  params: {
    name: pids.outputs.dbEnd
  }
  dependsOn: [
    pids
    jbossEAPDeployment
    postDeployment
  ]
}

resource asName_resource 'Microsoft.Compute/availabilitySets@${azure.apiVersionForAvailabilitySets}' = {
  name: asName_var
  location: location
  sku: {
    name: skuName
  }
  tags: union(_objTagsByResource['${identifier.availabilitySets}'], {
        'QuickstartName': 'JBoss EAP on RHEL (clustered, multi-VM)'
      })
  properties: {
    platformUpdateDomainCount: 2
    platformFaultDomainCount: 2
  }
  dependsOn: [
    failFastDeployment
  ]
}

module paygMultivmEndPid './modules/_pids/_pid.bicep' = {
  name: 'paygMultivmEndPid-${guidValue}'
  params: {
    name: pids.outputs.paygMultivmEnd
  }
  dependsOn: [
    dbConnectionEndPid
    postDeployment
  ]
}

output appGatewayEnabled bool = enableAppGWIngress
output mode string = operatingMode == name_managedDomain ? 'Domain Mode' : 'Standalone Mode'
output appHttpURL string = enableAppGWIngress ? uri(format('http://{0}/', appgwDeployment.outputs.appGatewayURL), 'eap-session-replication/') : ''
output appHttpsURL string = enableAppGWIngress ? uri(format('https://{0}/', appgwDeployment.outputs.appGatewaySecuredURL), 'eap-session-replication/') : ''
output adminUsername string = jbossEAPUserName
output adminConsole string = (operatingMode == name_managedDomain) ? (enableAppGWIngress ? (uri(format('http://{0}:9990', (reference(resourceId('Microsoft.Network/publicIPAddresses', '${vmName_var}${name_adminVmName}${name_publicIPAddress}')).dnsSettings.fqdn)), '')) : (uri(format('http://{0}:9990', (reference(resourceId('Microsoft.Network/networkInterfaces', '${nicName_var}0')).ipConfigurations[0].properties.privateIPAddress)), ''))) : ''
