@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location for all resources')
param location string = resourceGroup().location

@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object = {}

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_DS2_v2'

@description('Number of VMs to deploy')
param numberOfInstances int = 2

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = ''

var const_validateParameterScript = 'validate-parameters.sh'
var deploymentName = 'validate-parameters-and-fail-fast'
var const_azcliVersion = '2.15.0'
var const_arguments_validate_parameters = '${location} ${vmSize} ${numberOfInstances} ${connectSatellite} ${satelliteFqdn}'

resource validateParameters 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    arguments: const_arguments_validate_parameters
    primaryScriptUri: uri(artifactsLocation, '${const_validateParameterScript}${artifactsLocationSasToken}')
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
}
