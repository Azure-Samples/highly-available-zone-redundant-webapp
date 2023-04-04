param applicationName string
param location string
param tags object

// VARS
var vnet = '${applicationName}-vnet'

// Environment specific private link suffixes
// reference: https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns
var privateLinkFunctionsDnsNames = {
  AzureCloud: 'privatelink.azurewebsites.net'
  AzureUSGovernment: 'privatelink.azurewebsites.us'
  AzureChinaCloud: 'privatelink.chinacloudsites.cn'
}

var privateLinkRedisDnsNames = {
  AzureCloud: 'privatelink.redis.cache.windows.net'
  AzureUSGovernment: 'privatelink.redis.cache.usgovcloudapi.net'
  AzureChinaCloud: 'privatelink.redis.cache.chinacloudapi.cn'
}

var privateLinkServiceBusDnsNames = {
  AzureCloud: 'privatelink.servicebus.windows.net'
  AzureUSGovernment: 'privatelink.servicebus.usgovcloudapi.net'
  AzureChinaCloud: 'privatelink.servicebus.chinacloudapi.cn'
}

var privateLinkSearchDnsNames = {
  AzureCloud: 'privatelink.search.windows.net'
  AzureUSGovernment: 'privatelink.search.windows.us'
  AzureChinaCloud: 'privatelink.search.windows.net' // Azure China Cloud does not have Search service
}

var privateLinkCosmosDnsNames = {
  AzureCloud: 'privatelink.documents.azure.com'
  AzureUSGovernment: 'privatelink.documents.azure.us'
  AzureChinaCloud: 'privatelink.documents.azure.cn'
}

var privateLinkKeyVaultDnsNames = {
  AzureCloud: 'privatelink.vaultcore.azure.net'
  AzureUSGovernment: 'privatelink.vaultcore.usgovcloudapi.net'
  AzureChinaCloud: 'privatelink.vaultcore.azure.cn'
}


// VNET
//  Subnet consts
var WebappBackendSubnet = 0
var FunctionsBackendSubnet = 1
var FunctionsFrontendSubnet = 2
var StorageSubnet = 3
var RedisSubnet = 4
var ServiceBusSubnet = 5
var SearchSubnet = 6
var CosmosSubnet = 7
var KeyVaultSubnet = 8
var SqlServerSubnet = 9
var AppGwSubnet = 10

resource vnetResource 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnet
  location: location
  properties: {
    addressSpace:{
      addressPrefixes:[
        '10.0.0.0/20'
      ]
    }
    subnets:[
      // [0] Web app vnet integration subnet
      {
        name: 'webapp-backend-subnet'
        properties:{
          addressPrefix: '10.0.0.0/26'
          delegations: [
            {
              name: 'serverFarmDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]  
        }
      }
      // [1] Functions VNet integration subnet
      {
        name: 'functions-backend-subnet'
        properties:{
          addressPrefix: '10.0.0.64/26'          
          delegations: [
            {
              name: 'serverFarmDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      // [2] Functions private endpoint subnet
      {
        name: 'functions-frontend-subnet'
        properties:{
          addressPrefix: '10.0.1.0/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [3] Storage private endpoint subnet
      {
        name: 'storage-subnet'
        properties:{
          addressPrefix: '10.0.1.32/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [4] Azure Cache for Redis private endpoint subnet
      {
        name: 'redis-subnet'
        properties:{
          addressPrefix: '10.0.1.64/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [5] Service Bus private endpoint subnet
      {
        name: 'servicebus-subnet'
        properties:{
          addressPrefix: '10.0.1.96/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'  
        }
      }
      // [6] Azure Search private endpoint subnet
      {
        name: 'search-subnet'
        properties:{
          addressPrefix: '10.0.1.128/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [7] Cosmos DB private endpoint subnet
      {
        name: 'cosmos-subnet'
        properties:{
          addressPrefix: '10.0.1.160/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [8] Key Vault private endpoint subnet
      {
        name: 'keyvault-subnet'
        properties:{
          addressPrefix: '10.0.1.192/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [9] Azure SQL DB private endpoint subnet
      {
        name: 'sql-server-subnet'
        properties:{
          addressPrefix: '10.0.1.224/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [10] Application Gateway subnet
      {
        name: 'appgw-subnet'
        properties:{
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  tags: tags
}


// PRIVATE DNS ZONES
resource privateFunctionsDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkFunctionsDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false    // * Always false for Private Endpoint DNS Zone VNet links
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateBlobsDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateFilesDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateTablesDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateQueuesDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateRedisDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkRedisDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateServicebusDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkServiceBusDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateCogSearchDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkSearchDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateCosmosDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkCosmosDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateKeyvaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkKeyVaultDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}

resource privateSqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(vnetResource.id, '/'))}-vnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetResource.id
      }
    }
  }
}


output privateDnsZoneIds object = {
  blobs: privateBlobsDnsZone.id
  cogSearch: privateCogSearchDnsZone.id
  cosmos: privateCosmosDnsZone.id
  files: privateFilesDnsZone.id
  functions: privateFunctionsDnsZone.id
  keyvault: privateKeyvaultDnsZone.id
  queues: privateQueuesDnsZone.id
  redis: privateRedisDnsZone.id
  servicebus: privateServicebusDnsZone.id
  sql: privateSqlDnsZone.id
  tables: privateTablesDnsZone.id
}

output subnetIds object = {
  appGateway: vnetResource.properties.subnets[AppGwSubnet].id
  appServices: vnetResource.properties.subnets[WebappBackendSubnet].id
  cosmos: vnetResource.properties.subnets[CosmosSubnet].id
  functionsFrontend: vnetResource.properties.subnets[FunctionsFrontendSubnet].id
  functionsBackend: vnetResource.properties.subnets[FunctionsBackendSubnet].id
  keyvault: vnetResource.properties.subnets[KeyVaultSubnet].id
  redis: vnetResource.properties.subnets[RedisSubnet].id
  search: vnetResource.properties.subnets[SearchSubnet].id
  serviceBus: vnetResource.properties.subnets[ServiceBusSubnet].id
  sqlServer: vnetResource.properties.subnets[SqlServerSubnet].id 
  storage: vnetResource.properties.subnets[StorageSubnet].id
  webappBackend: vnetResource.properties.subnets[WebappBackendSubnet].id
}
