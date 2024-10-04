param identity object = {}
param location string
param permission object = {
  certificates: [
    'get'
    'list'
    'update'
    'create'
  ]
}

@description('Price tier for Key Vault.')
param sku string = 'Standard'

@description('Subject name to create a certificate.')
param subjectName string = ''

@description('Current deployment time. Used as a tag in deployment script.')
param keyVaultName string = 'GEN_UNIQUE'

module keyVaultwithSelfSignedAppGatewaySSLCert '_keyvault/_keyvaultWithNewCert.bicep' = {
  name: 'kv-appgw-selfsigned-certificate-deployment'
  params: {
    identity: identity
    keyVaultName: keyVaultName
    location: location
    permission: permission
    subjectName: subjectName
    sku: sku
  }
}

output keyVaultName string = keyVaultwithSelfSignedAppGatewaySSLCert.outputs.keyVaultName
output sslCertDataSecretName string = keyVaultwithSelfSignedAppGatewaySSLCert.outputs.secretName
output sslCertPwdSecretName string = ''
output sslBackendCertDataSecretName string = ''
