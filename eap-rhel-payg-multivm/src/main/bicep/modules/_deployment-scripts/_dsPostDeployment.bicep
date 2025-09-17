param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param location string
param name string = ''
param identity object = {}
param resourceGroupName string
@description('Tags for the resources.')
param tagsByResource object
param guidTag string
param utcValue string = utcNow()

var const_scriptLocation = uri(_artifactsLocation, 'scripts/')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: name
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.40.0'
    arguments: '-l ${location}'
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP_NAME'
        value: resourceGroupName
      }
      {
        name: 'GUID_TAG'
        value: guidTag
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, 'post-deployment.sh${_artifactsLocationSasToken}')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
  tags: tagsByResource['${identifier.deploymentScripts}']
}
