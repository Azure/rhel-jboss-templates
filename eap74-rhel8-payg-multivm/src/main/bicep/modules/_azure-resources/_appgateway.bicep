@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('jbossgw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param gatewaySslCertName string = 'appGatewaySslCert'
param location string
param noSslCertPsw bool = false
@secure()
param sslCertData string = newGuid()
@secure()
param sslCertPswData string = newGuid()
param utcValue string = utcNow()
param appGatewayName string = 'jbossappgw'
param _pidAppgwEnd string = 'pid-networking-appgateway-end'
param _pidAppgwStart string = 'pid-networking-appgateway-start'

var const_sslCertPsw = (noSslCertPsw) ? '' : sslCertPswData
var name_appGateway = appGatewayName
var const_appGatewayFrontEndHTTPPort = 80
var const_appGatewayFrontEndHTTPSPort = 443
// var const_appGatewayAdminFrontEndHTTPSPort = 9990
var const_backendPort = 8080
// var const_adminBackendPort = 9990
var name_managedBackendAddressPool = 'managedNodeBackendPool'
// var name_adminBackendAddressPool = 'adminNodeBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_httpListener = 'managedHttpListener'
var name_httpPort = 'managedHttpPort'
var name_httpSetting = 'managedHttpSetting'
// var name_adminHttpSetting = 'adminHttpSetting'
var name_httpsListener = 'managedHttpsListener'
var name_httpsPort = 'managedHttpsPort'
// var name_adminHttpListener = 'adminHttpListener'
// var name_adminHttpPort = 'adminHttpPort'
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_managedBackendAddressPool)
// var ref_adminBackendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_adminBackendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
// var ref_adminBackendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_adminHttpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
// var ref_frontendAdminHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_adminHttpPort)
var ref_frontendHTTPSPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpsPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)
var ref_httpsListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpsListener)
// var ref_adminHttpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_adminHttpListener)
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
  name: 'pid-app-gateway-start-deployment'
  params: {
    name: _pidAppgwStart
  }
}

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
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
}

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@2022-05-01' = {
  name: name_appGateway
  location: location
  tags: {
    'managed-by-k8s-ingress': 'true'
  }
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
          password: const_sslCertPsw
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
      // {
      //   name: name_adminHttpPort
      //   properties: {
      //     port: const_appGatewayAdminFrontEndHTTPSPort
      //   }
      // }
    ]
    backendAddressPools: [
      {
        name: name_managedBackendAddressPool
        properties: {}
      }
      // {
      //   name: name_adminBackendAddressPool
      //   properties: {}
      // }
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
      // {
      //   name: name_adminHttpListener
      //   properties: {
      //     protocol: 'Http'
      //     frontendIPConfiguration: {
      //       id: ref_frontendIPConfiguration
      //     }
      //     frontendPort: {
      //       id: ref_frontendAdminHTTPPort
      //     }
      //   }
      // }
    ]
    backendHttpSettingsCollection: [
      {
        name: name_httpSetting
        properties: {
          port: const_backendPort
          protocol: 'Http'
        }
      }
      // {
      //   name: name_adminHttpSetting
      //   properties: {
      //     port: const_adminBackendPort
      //     protocol: 'Http'
      //   }
      // }
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
      // {
      //   name: 'adminHttpRoutingRule'
      //   properties: {
      //     priority: 5
      //     httpListener: {
      //       id: ref_adminHttpListener
      //     }
      //     backendAddressPool: {
      //       id: ref_adminBackendAddressPool
      //     }
      //     backendHttpSettings: {
      //       id: ref_adminBackendHttpSettings
      //     }
      //   }
      // }
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
  name: 'pid-app-gateway-end-deployment'
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
output appGatewayURL string = uri(format('http://{0}/', reference(gatewayPublicIP.id).dnsSettings.fqdn), '')
output appGatewaySecuredURL string = uri(format('https://{0}/', reference(gatewayPublicIP.id).dnsSettings.fqdn), '')
