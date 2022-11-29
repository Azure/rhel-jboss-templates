@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location')
param location string = resourceGroup().location

@description('Domain Prefix')
param domain string = 'domain'

@secure()
@description('Pull secret from cloud.redhat.com. The json should be input as a string')
param pullSecret string

@description('Name of ARO vNet')
param clusterVnetName string = 'aro-vnet'

@description('ARO vNet Address Space')
param clusterVnetCidr string = '10.100.0.0/15'

@description('Worker node subnet address space')
param workerSubnetCidr string = '10.100.70.0/23'

@description('Master node subnet address space')
param masterSubnetCidr string = '10.100.76.0/24'

@description('Master Node VM Type')
param vmSize string = 'Standard_D8s_v3'

@description('Worker Node VM Type')
param workerVmSize string = 'Standard_D4s_v3'

@description('Worker Node Disk Size in GB')
@minValue(128)
@maxValue(256)
param workerVmDiskSize int = 128

@description('Number of Worker Nodes')
@minValue(3)
@maxValue(5)
param workerCount int = 3

@description('Cidr for Pods')
param podCidr string = '10.128.0.0/14'

@metadata({
  description: 'Cidr of service'
})
param serviceCidr string = '172.30.0.0/16'

@description('Unique name for the cluster')
param clusterName string = 'aro-cluster'

@description('Tags for resources')
param tags object = {
  env: 'Dev'
  dept: 'Ops'
}

@description('Api Server Visibility')
@allowed([
  'Private'
  'Public'
])
param apiServerVisibility string = 'Public'

@description('Ingress Visibility')
@allowed([
  'Private'
  'Public'
])
param ingressVisibility string = 'Public'

@description('The application ID of an Azure Active Directory client application')
param aadClientId string = ''

@description('The secret of an Azure Active Directory client application')
@secure()
param aadClientSecret string

@description('The service principal Object ID of an Azure Active Directory client application')
param aadObjectId string = ''

@description('The service principal Object ID of the Azure Red Hat OpenShift Resource Provider')
param rpObjectId string = ''

param guidValue string = take(replace(newGuid(), '-', ''), 6) 

var const_suffix = take(replace(guidValue, '-', ''), 6)
var const_identityName = 'uami${const_suffix}'
var const_contribRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_roleAssignmentName = guid(format('{0}{1}Role assignment in group{0}', resourceGroup().id, ref_identityId))
var ref_identityId = resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', const_identityName)
var const_cmdToGetKubeadminCredentials = 'az aro list-credentials -g ${resourceGroup().name} -n ${clusterName}'
var const_cmdToGetKubeadminUsername = '${const_cmdToGetKubeadminCredentials} --query kubeadminUsername -o tsv'
var const_cmdToGetKubeadminPassword = '${const_cmdToGetKubeadminCredentials} --query kubeadminPassword -o tsv'
var const_cmdToGetApiServer = 'az aro show -g ${resourceGroup().name} -n ${clusterName} --query apiserverProfile.url -o tsv'

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-0cc5f6a1-9633-40d9-bc00-f010ad5b365a-partnercenter'
  params: {}
}

resource uami_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: const_identityName
  location: location
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: const_identityName
}

resource uamiRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name_roleAssignmentName
  dependsOn:[
    uami_resource
    roleResourceDefinition
  ]
  properties:{
    roleDefinitionId: roleResourceDefinition.id
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource clusterVnetName_resource 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: clusterVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        clusterVnetCidr
      ]
    }
    subnets: [
      {
        name: 'master'
        properties: {
          addressPrefix: masterSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'worker'
        properties: {
          addressPrefix: workerSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
    ]
  }
}

resource vnetRef 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: clusterVnetName
}

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: const_contribRole
}

resource assignRoleAppSp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployment().name, vnetRef.id, 'assignRoleAppSp')
  scope: vnetRef
  properties: {
    principalId: aadObjectId
    roleDefinitionId: roleResourceDefinition.id
  }
  dependsOn: [
    vnetRef
    roleResourceDefinition
    clusterVnetName_resource
  ]
}

resource assignRoleRpSp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployment().name, vnetRef.id, 'assignRoleRpSp')
  scope: vnetRef
  properties: {
    principalId: rpObjectId
    roleDefinitionId: roleResourceDefinition.id
  }
  dependsOn: [
    vnetRef
    roleResourceDefinition
    clusterVnetName_resource
  ]
}

resource clusterName_resource 'Microsoft.RedHatOpenShift/openShiftClusters@2022-04-01' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    clusterProfile: {
      domain: '${domain}${const_suffix}'
      resourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', 'MC_${resourceGroup().name}_${clusterName}_${location}')
      pullSecret: pullSecret
      fipsValidatedModules: 'Disabled'
    }
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
    }
    servicePrincipalProfile: {
      clientId: aadClientId
      clientSecret: aadClientSecret
    }
    masterProfile: {
      vmSize: vmSize
      subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'master')
      encryptionAtHost: 'Disabled'
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: workerVmSize
        diskSizeGB: workerVmDiskSize
        subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'worker')
        count: workerCount
        encryptionAtHost:'Disabled'
      }
    ]
    apiserverProfile: {
      visibility: apiServerVisibility
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: ingressVisibility
      }
    ]
  }
  dependsOn: [
    assignRoleAppSp
    assignRoleRpSp
  ]
}

module jbossEAPDeployment 'modules/_deployment-scripts/_ds-jbossSetup.bicep' = {
  name: 'jboss-setup'
  params: {
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    clusterName: clusterName
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', const_identityName)}': {}
      }
    }
  }
  dependsOn: [
    clusterName_resource
  ]
}

output cmdToGetKubeadminCredentials string = const_cmdToGetKubeadminCredentials
output cmdToLoginWithKubeadmin string = 'oc login $(${const_cmdToGetApiServer}) -u $(${const_cmdToGetKubeadminUsername}) -p $(${const_cmdToGetKubeadminPassword})'
