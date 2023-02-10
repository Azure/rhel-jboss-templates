param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param location string
param name string = ''
param identity object = {}
param resourceGroupName string
param nicName string

param utcValue string = utcNow()

var const_scriptLocation = uri(_artifactsLocation, 'scripts/')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: name
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.41.0'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP_NAME'
        value: resourceGroupName
      }
      {
        name: 'NIC_NAME'
        value: nicName
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, 'post-deployment.sh${_artifactsLocationSasToken}')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
