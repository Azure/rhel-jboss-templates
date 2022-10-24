@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location for all resources')
param location string = resourceGroup().location

@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object = {}

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

@description('Storage account name created in main')
param eapStorageAccountName string = ''

@description('Container name created in main')
param containerName string = ''

@description('Number of VMs to deploy')
param numberOfInstances int = 2

@description('Name of the admin virtual machines')
param adminVmName string = 'jbosseap-byos-server'

@description('Name of the virtual machines')
param vmName string = 'jbosseap-byos-server'

@description('Number of server instances per host')
param numberOfServerInstances int = 1

@description('Managed domain mode or standalone mode')
@allowed([
  'standalone'
  'managed-domain'
])
param operatingMode string = 'managed-domain'

@description('Specify whether to create a new or existing virtual network for the VM.')
@allowed([
  'new'
  'existing'
])
param virtualNetworkNewOrExisting string = 'new'

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = ''

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = ''

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = ''

var const_scriptLocation = uri(artifactsLocation, 'scripts/')
var const_setupJBossScript = 'jbosseap-setup-redhat.sh'
var const_setupDomainMasterScript = 'jbosseap-setup-master.sh'
var const_setupDomainSlaveScript = 'jbosseap-setup-slave.sh'
var const_setupDomainStandaloneScript = 'jbosseap-setup-standalone.sh'
var const_azcliVersion = '2.15.0'
var scriptFolder = 'scripts'
// A workaround for publishing private plan in Partner center, see issue: https://github.com/Azure/rhel-jboss-templates/issues/108
// This change is coupled with .github/workflows/validate-byos-multivm.yaml#81
var fileFolder = 'scripts'
var fileToBeDownloaded = 'eap-session-replication.war'
var scriptArgs = '-a \'${uri(artifactsLocation, '.')}\' -t \'${empty(artifactsLocationSasToken) ? '?' : artifactsLocationSasToken}\' -p ${fileFolder} -f ${fileToBeDownloaded} -s ${scriptFolder}'
var const_arguments = '${scriptArgs} ${jbossEAPUserName} ${base64(jbossEAPPassword)} ${rhsmUserName} ${base64(rhsmPassword)} ${rhsmPoolEAP} ${rhsmPoolRHEL} ${eapStorageAccountName} ${containerName} ${resourceGroup().name} ${numberOfInstances} ${adminVmName} ${vmName} ${numberOfServerInstances} ${operatingMode} ${virtualNetworkNewOrExisting} ${connectSatellite} ${base64(satelliteActivationKey)} ${base64(satelliteOrgName)} ${satelliteFqdn}'


resource jbossEAPSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'jbosseap-setup'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
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
}
