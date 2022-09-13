@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location for all resources')
param location string = resourceGroup().location

@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object = {}

@description('Unique name for the cluster')
param clusterName string

var const_scriptLocation = uri(artifactsLocation, 'scripts/')
var const_setupJBossScript = 'jboss-setup.sh'
var const_eapOperatorSubscriptionYaml = 'eap-operator-sub.yaml'
var const_azcliVersion = '2.15.0'

resource jbossSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'jboss-setup'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'CLUSTER_NAME'
        value: clusterName
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_setupJBossScript}${artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_eapOperatorSubscriptionYaml}${artifactsLocationSasToken}')
    ]
    cleanupPreference:'OnSuccess'
    retentionInterval: 'P1D'
  }
}
