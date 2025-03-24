@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('jbossgw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param gatewaySslCertName string = 'appGatewaySslCert'
param location string
@secure()
param sslCertData string = newGuid()
param utcValue string = utcNow()
param appGatewayName string = 'jbossappgw'
param _pidAppgwEnd string = 'pid-networking-appgateway-end'
param _pidAppgwStart string = 'pid-networking-appgateway-start'
param enableCookieBasedAffinity bool = false
param guidValue string = ''
@description('${label.tagsLabel}')
param tagsByResource object

var name_appGateway = appGatewayName
var const_appGatewayFrontEndHTTPPort = 80
var const_appGatewayFrontEndHTTPSPort = 443
var const_backendPort = 8080
var name_managedBackendAddressPool = 'managedNodeBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_httpListener = 'managedHttpListener'
var name_httpPort = 'managedHttpPort'
var name_httpSetting = 'managedHttpSetting'
var name_httpsListener = 'managedHttpsListener'
var name_httpsPort = 'managedHttpsPort'
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_managedBackendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
var ref_frontendHTTPSPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpsPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)
var ref_httpsListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpsListener)
var ref_publicIPAddress = resourceId('Microsoft.Network/publicIPAddresses', gatewayPublicIPAddressName)
var ref_sslCertificate = resourceId('Microsoft.Network/applicationGateways/sslCertificates', name_appGateway, gatewaySslCertName)
var obj_frontendIPConfigurations1 = [
  {
    name: name_frontEndIPConfig
    properties: {
      publicIPAddress: {
        id: ref_publicIPAddress
      }
    }
  }
]

module pidAppgwStart '../_pids/_pid.bicep' = {
  name: 'pid-app-gateway-start-deployment-${guidValue}'
  params: {
    name: _pidAppgwStart
  }
}

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = {
  name: gatewayPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
  tags: tagsByResource['${identifier.publicIPAddresses}']
}

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@${azure.apiVersionForApplicationGateways}' = {
  name: name_appGateway
  location: location
  tags: union(tagsByResource['${identifier.applicationGateways}'], {
        'managed-by-k8s-ingress': 'true'
  })
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslCertificates: [
      {
        name: gatewaySslCertName
        properties: {
          data: sslCertData
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: obj_frontendIPConfigurations1
    frontendPorts: [
      {
        name: name_httpPort
        properties: {
          port: const_appGatewayFrontEndHTTPPort
        }
      }
      {
        name: name_httpsPort
        properties: {
          port: const_appGatewayFrontEndHTTPSPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: name_managedBackendAddressPool
        properties: {}
      }
    ]
    httpListeners: [
      {
        name: name_httpListener
        properties: {
          protocol: 'Http'
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPPort
          }
        }
      }
      {
        name: name_httpsListener
        properties: {
          protocol: 'Https'
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPSPort
          }
          sslCertificate: {
            id: ref_sslCertificate
          }
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: name_httpSetting
        properties: {
          port: const_backendPort
          protocol: 'Http'
          cookieBasedAffinity: enableCookieBasedAffinity? 'Enabled' :'Disabled'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'managedNodeHttpRoutingRule'
        properties: {
          priority: 3
          httpListener: {
            id: ref_httpListener
          }
          backendAddressPool: {
            id: ref_backendAddressPool
          }
          backendHttpSettings: {
            id: ref_backendHttpSettings
          }
        }
      }
      {
        name: 'managedNodeHttpsRoutingRule'
        properties: {
          priority: 4
          httpListener: {
            id: ref_httpsListener
          }
          backendAddressPool: {
            id: ref_backendAddressPool
          }
          backendHttpSettings: {
            id: ref_backendHttpSettings
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 3
    }
  }
  dependsOn: [
    gatewayPublicIP
  ]
}



module pidAppgwEnd '../_pids/_pid.bicep' = {
  name: 'pid-app-gateway-end-deployment-${guidValue}'
  params: {
    name: _pidAppgwEnd
  }
  dependsOn: [
    wafv2AppGateway
  ]
}

output appGatewayAlias string = reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewayId string = wafv2AppGateway.id
output appGatewayName string = name_appGateway
output appGatewayURL string = reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewaySecuredURL string = reference(gatewayPublicIP.id).dnsSettings.fqdn
