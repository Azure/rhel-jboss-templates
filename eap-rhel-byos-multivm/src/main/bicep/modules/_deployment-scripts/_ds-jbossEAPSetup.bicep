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

@description('Please enter a Graceful Shutdown Timeout in seconds')
param gracefulShutdownTimeout string

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
param satelliteActivationKey string = newGuid()

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = newGuid()

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = newGuid()

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'openjdk17'

@description('NIC name prefix')
param nicName string

@description('Boolean value indicating if user wants to enable database connection.')
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

var const_scriptLocation = uri(artifactsLocation, 'scripts/')
var const_setupJBossScript = 'jbosseap-setup-redhat.sh'
var const_setupDomainMasterScript = 'jbosseap-setup-master.sh'
var const_setupDomainSlaveScript = 'jbosseap-setup-slave.sh'
var const_setupDomainStandaloneScript = 'jbosseap-setup-standalone.sh'
var const_enableElytronSe17DomainCli = 'enable-elytron-se17-domain.cli'
var const_deploySampleAppScript = 'deploy-sample-app.sh'
var const_azcliVersion = '2.15.0'
var scriptFolder = 'scripts'
// A workaround for publishing private plan in Partner center, see issue: https://github.com/Azure/rhel-jboss-templates/issues/108
// This change is coupled with .github/workflows/validate-byos-multivm.yaml#81
var fileFolder = 'scripts'
var fileToBeDownloaded = 'eap-session-replication.war'

resource jbossEAPSetup 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'jbosseap-setup'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
        name: 'ARTIFACTS_LOCATION'
        value: '\'${uri(artifactsLocation, '.')}\''
      }
      {
        name: 'ARTIFACTS_LOCATION_SAS_TOKEN'
        value: empty(artifactsLocationSasToken) ? '?' : artifactsLocationSasToken
      }
      {
        name: 'PATH_TO_FILE'
        value: fileFolder
      }
      {
        name: 'FILE_TO_DOWNLOAD'
        value: fileToBeDownloaded
      }
      {
        name: 'PATH_TO_SCRIPT'
        value: scriptFolder
      }
      {
        name: 'JBOSS_EAP_USER'
        value: jbossEAPUserName
      }
      {
        name: 'JBOSS_EAP_PASSWORD_BASE64'
        secureValue: base64(jbossEAPPassword)
      }
      {
        name: 'gracefulShutdownTimeout'
        secureValue: base64(gracefulShutdownTimeout)
      }
      {
        name: 'RHSM_USER'
        value: rhsmUserName
      }
      {
        name: 'RHSM_PASSWORD_BASE64'
        secureValue: base64(rhsmPassword)
      }
      {
        name: 'EAP_POOL'
        secureValue: rhsmPoolEAP
      }
      {
        name: 'RHEL_POOL'
        secureValue: rhsmPoolRHEL
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: eapStorageAccountName
      }
      {
        name: 'CONTAINER_NAME'
        value: containerName
      }
      {
        name: 'RESOURCE_GROUP_NAME'
        value: resourceGroup().name
      }
      {
        name: 'NUMBER_OF_INSTANCE'
        value: string(numberOfInstances)
      }
      {
        name: 'ADMIN_VM_NAME'
        value: adminVmName
      }
      {
        name: 'VM_NAME_PREFIX'
        value: vmName
      }
      {
        name: 'NUMBER_OF_SERVER_INSTANCE'
        value: string(numberOfServerInstances)
      }
      {
        name: 'CONFIGURATION_MODE'
        value: operatingMode
      }
      {
        name: 'VNET_NEW_OR_EXISTING'
        value: virtualNetworkNewOrExisting
      }
      {
        name: 'CONNECT_SATELLITE'
        value: string(connectSatellite)
      }
      {
        name: 'SATELLITE_ACTIVATION_KEY_BASE64'
        secureValue: base64(satelliteActivationKey)
      }
      {
        name: 'SATELLITE_ORG_NAME_BASE64'
        value: base64(satelliteOrgName)
      }
      {
        name: 'SATELLITE_VM_FQDN'
        value: satelliteFqdn
      }
      {
        name: 'JDK_VERSION'
        value: jdkVersion
      }
      {
        name: 'NIC_NAME'
        value: nicName
      }
      {
        name: 'ENABLE_DB'
        value: string(enableDB)
      }
      {
        name: 'DATABASE_TYPE'
        value: databaseType
      }
      {
        name: 'JDBC_DATA_SOURCE_JNDI_NAME_BASE64'
        value: base64(jdbcDataSourceJNDIName)
      }
      {
        name: 'DS_CONNECTION_URL_BASE64'
        value: base64(dsConnectionURL)
      }
      {
        name: 'DB_USER_BASE64'
        value: base64(dbUser)
      }
      {
        name: 'DB_PASSWORD_BASE64'
        secureValue: base64(dbPassword)
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_setupJBossScript}${artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_setupDomainMasterScript}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_setupDomainSlaveScript}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_setupDomainStandaloneScript}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_enableElytronSe17DomainCli}${artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_deploySampleAppScript}${artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
