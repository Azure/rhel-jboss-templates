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

@description('User name for Red Hat subscription Manager')
param rhsmUserName string = newGuid()

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
param rhsmPoolEAP string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have RHEL entitlement). Mandartory if you select the BYOS RHEL OS License Type')
param rhsmPoolRHEL string = newGuid()

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_DS2_v2'

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'openjdk17'

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
  'New'
  'Existing'
])
param bootStorageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'boot${uniqueString(resourceGroup().id)}'

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

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = ''

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = ''

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = ''

param guidValue string = take(replace(newGuid(), '-', ''), 6)

@description('Price tier for Key Vault.')
param keyVaultSku string = 'Standard'

@description('UTC value for generating unique names')
param utcValue string = utcNow()

@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'jbossgw'

@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data for Appliation Gateway frontend TLS/SSL.')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'

@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false

var name_managedDomain = 'managed-domain'
var name_fileshare = 'jbossshare'
var containerName = 'eapblobcontainer'
var eapStorageAccountName = 'jbosstrg${uniqueString(resourceGroup().id)}'
var eapstorageReplication = 'Standard_LRS'
var vmName_var = vmName
var asName_var = asName
var skuName = 'Aligned'
var nicName_var = 'jbosseap-server-nic'
var privateSaEndpointName_var = 'saep${uniqueString(resourceGroup().id)}'
var bootDiagnosticsCheck = ((bootStorageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var bootStorageName_var = ((bootStorageNewOrExisting == 'Existing') ? existingStorageAccount : bootStorageAccountName)
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
  publisher: 'redhat'
  offer: 'rhel-byos'
  sku: 'rhel-lvm86-gen2'
  version: 'latest'
}
var plan = {
  name: 'rhel-lvm86-gen2'
  publisher: 'redhat'
  product: 'rhel-byos'
}

var name_failFastDsName = format('failFast{0}', guidValue)
var name_jbossEAPDsName = 'jbosseap-setup'
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}
var name_keyVaultName = take('jboss-kv${guidValue}', 24)
var name_dnsNameforApplicationGateway = '${dnsNameforApplicationGateway}${take(uniqueString('${utcValue}${resourceGroup().id}'), 6)}'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}', 63)
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var name_appgwFrontendSSLCertName = 'appGatewaySslCert'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
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
var name_networkSecurityGroup = 'jboss-nsg'
var name_appGatewayPublicIPAddress = 'gwip'

/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-1879addb-1fa9-4225-8bd2-6d0a1ffc5dc0-partnercenter'
  params: {}
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

module failFastDeployment 'modules/_deployment-scripts/_ds-failfast.bicep' = {
  name: name_failFastDsName
  params: {
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    identity: obj_uamiForDeploymentScript
    vmSize: vmSize
    numberOfInstances: numberOfInstances
    connectSatellite: connectSatellite
    satelliteFqdn: satelliteFqdn
  }
  dependsOn: [
    partnerCenterPid
    uamiDeployment
  ]
}

module appgwSecretDeployment 'modules/_azure-resources/_keyvaultForGateway.bicep' = if (enableAppGWIngress) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    identity: obj_uamiForDeploymentScript
    location: location
    sku: keyVaultSku
    subjectName: format('CN={0}', const_azureSubjectName)
    keyVaultName: name_keyVaultName
  }
  dependsOn: [
    failFastDeployment
  ]
}

// Get existing VNET.
resource existingVnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroupName)
}

// Get existing subnet.
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: subnetForAppGateway
  parent: existingVnet
}

module appgwDeployment 'modules/_appgateway.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment'
  params: {
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: name_dnsNameforApplicationGateway
    gatewayPublicIPAddressName: name_appGatewayPublicIPAddress
    gatewaySubnetId: virtualNetworkNewOrExisting == 'new' ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetForAppGateway) : existingSubnet.id
    gatewaySslCertName: name_appgwFrontendSSLCertName
    location: location
    sslCertDataSecretName: (enableAppGWIngress ? appgwSecretDeployment.outputs.sslCertDataSecretName : keyVaultSSLCertDataSecretName)
    _pidAppgwStart: pids.outputs.appgwStart
    _pidAppgwEnd: pids.outputs.appgwEnd
    keyVaultName: name_keyVaultName
    enableCookieBasedAffinity: enableCookieBasedAffinity
  }
  dependsOn: [
    appgwSecretDeployment
    pids
    virtualNetworkName_resource
  ]
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@2022-05-01' = if (bootDiagnosticsCheck) {
  name: bootStorageName_var
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  dependsOn: [
    failFastDeployment
  ]
}

resource eapStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
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
  dependsOn: [
    failFastDeployment
  ]
}

resource eapStorageAccountNameContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${eapStorageAccountName}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    eapStorageAccount
    failFastDeployment
  ]
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = if (operatingMode == name_managedDomain) {
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

resource symbolicname 'Microsoft.Network/privateEndpoints@2022-01-01' = if (operatingMode == name_managedDomain) {
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
      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
    }
  }
  dependsOn: [
    eapStorageAccount
  ]
}

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = if (enableAppGWIngress && virtualNetworkNewOrExisting == 'new') {
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
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2022-05-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL (clustered, multi-VM)'
  }
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: enableAppGWIngress ? property_subnet_with_app_gateway : property_subnet_without_app_gateway
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = [for i in range(0, numberOfInstances): if (enableAppGWIngress) {
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
}]

resource nicName 'Microsoft.Network/networkInterfaces@2022-05-01' = [for i in range(0, numberOfInstances): {
  name: '${nicName_var}${i}'
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
  ]
}]

resource vmName_resource 'Microsoft.Compute/virtualMachines@2022-08-01' = [for i in range(0, numberOfInstances): {
  name: (operatingMode == name_managedDomain) ? (i == 0 ? '${vmName_var}${name_adminVmName}' : '${vmName_var}${i}') : '${vmName_var}${i}'
  location: location
  plan: plan
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
  dependsOn: [
    nicName
    bootStorageName
    virtualNetworkName_resource
    eapStorageAccount
  ]
}]

module jbossEAPDeployment 'modules/_deployment-scripts/_ds-jbossEAPSetup.bicep' = {
  name: name_jbossEAPDsName
  params: {
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    identity: obj_uamiForDeploymentScript
    jbossEAPUserName: jbossEAPUserName
    jbossEAPPassword: jbossEAPPassword
    rhsmUserName: rhsmUserName
    rhsmPassword: rhsmPassword
    rhsmPoolEAP: rhsmPoolEAP
    rhsmPoolRHEL: rhsmPoolRHEL
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
  }
  dependsOn: [
    vmName_resource
    eapStorageAccount
  ]
}

resource asName_resource 'Microsoft.Compute/availabilitySets@2022-08-01' = {
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

output appHttpURL string = (enableAppGWIngress && (operatingMode != name_managedDomain)) ? uri(format('http://{0}/', appgwDeployment.outputs.appGatewayURL), 'eap-session-replication') : ''
output appHttpsURL string = (enableAppGWIngress && (operatingMode != name_managedDomain)) ? uri(format('https://{0}/', appgwDeployment.outputs.appGatewaySecuredURL), 'eap-session-replication') : ''
output adminConsole string = (operatingMode == name_managedDomain) ? (enableAppGWIngress ? (uri(format('http://{0}:9990', (reference(resourceId('Microsoft.Network/publicIPAddresses', '${vmName_var}${name_adminVmName}${name_publicIPAddress}')).dnsSettings.fqdn)), '')) : (uri(format('http://{0}:9990', (reference(resourceId('Microsoft.Network/networkInterfaces', '${nicName_var}0')).ipConfigurations[0].properties.privateIPAddress)), ''))) : ''
