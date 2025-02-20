@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('jbossgw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param gatewaySslCertName string = 'appGatewaySslCert'
param location string
param utcValue string = utcNow()
param appGatewayName string = 'jbossappgw'
param _pidAppgwEnd string = 'pid-networking-appgateway-end'
param _pidAppgwStart string = 'pid-networking-appgateway-start'
param keyVaultName string = 'keyVaultName'
param sslCertDataSecretName string = 'sslCertDataSecretName'
param enableCookieBasedAffinity bool = false
param guidValue string = ''


var name_appGateway = appGatewayName

// get key vault object from a resource group
resource existingKeyvault 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' existing = {
  name: keyVaultName
  scope: resourceGroup()
}

module appgwDeployment1 './_azure-resources/_appGateway.bicep' = {
  name: 'app-gateway-deployment-with-self-signed-cert-${guidValue}'
  params: {
    guidValue: guidValue
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    gatewayPublicIPAddressName: gatewayPublicIPAddressName
    gatewaySubnetId: gatewaySubnetId
    gatewaySslCertName: gatewaySslCertName
    location: location
    sslCertData: existingKeyvault.getSecret(sslCertDataSecretName)
    _pidAppgwStart: _pidAppgwStart
    _pidAppgwEnd: _pidAppgwEnd
    enableCookieBasedAffinity: enableCookieBasedAffinity
  }
  dependsOn: [
    existingKeyvault
  ]
}

output appGatewayAlias string = appgwDeployment1.outputs.appGatewayAlias
output appGatewayId string = appgwDeployment1.outputs.appGatewayId
output appGatewayName string = appgwDeployment1.outputs.appGatewayName
output appGatewayURL string = appgwDeployment1.outputs.appGatewayURL
output appGatewaySecuredURL string = appgwDeployment1.outputs.appGatewaySecuredURL
