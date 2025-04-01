@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location for all resources')
param location string = resourceGroup().location

@description('Flag indicating whether to create a new cluster or not')
param createCluster bool = true

@description('The application ID of an Microsoft Entra ID client application')
param aadClientId string = ''

@description('The service principal Object ID of an Microsoft Entra ID client application')
param aadObjectId string = ''

@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object = {}
param guidValue string = ''

var const_scriptLocation = uri(artifactsLocation, 'scripts/')
var const_preflightScript = 'preflight.sh'
var const_azcliVersion = '2.53.0'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'jboss-preflight-${guidValue}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
          name: 'CREATE_CLUSTER'
          value: createCluster
      }
      {
          name: 'AAD_CLIENT_ID'
          value: aadClientId
      }
      {
          name: 'AAD_OBJECT_ID'
          value: aadObjectId
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_preflightScript}${artifactsLocationSasToken}')
    cleanupPreference:'OnSuccess'
    retentionInterval: 'P1D'
  }
}

