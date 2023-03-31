@description('Optional. A name that will be prepended to all deployed resources. Defaults to an alphanumeric id that is unique to the resource group.')
param applicationName string = 'zrhaweb-${uniqueString(resourceGroup().id)}'

@description('Optional. The Azure region (location) to deploy to. Must be a region that supports availability zones. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Optional. The Azure region (location) to deploy Static Web Apps to. Even though Static Web Apps is a non-regional resource, a location must be chosen from a limited subset of regions. Defaults to the value of the location parameter.')
param staticWebAppLocation string = location

@description('Optional. An Azure tags object for tagging parent resources that support tags.')
param tags object = {
  Project: 'Azure highly-available zone-redundant web application'
}

@description('Optional. SQL admin username. Defaults to \'\${applicationName}-admin\'')
param sqlAdmin string = '${applicationName}-admin'

@description('Optional. A password for the Azure SQL server admin user. Defaults to a new GUID.')
@secure()
param sqlAdminPassword string = newGuid()

@description('Optional. Name of the SQL database to create. Defaults to \'\${applicationName}-sql-db\'')
param sqlDatabaseName string = '${applicationName}-sql-db'

@description('Optional. Name of the Cosmos database to create. Defaults to \'\${applicationName}-db\'')
param cosmosDatabaseName string = '${applicationName}-db'

@description('Optional. Name of the Cosmos DB container to create. Defaults to \'Container1\'')
param cosmosContainerName string = 'Container1'

@description('Optional. Array of properties that make up the Partition Key for the Cosmos DB container. Defaults to [ \'id\' ].')
param cosmosPartitionKeys array = [ '/id' ]

@description('Optional. Name of the Service Bus queue to create. Defaults to \'Queue1\'')
param servicebusQueueName string = 'Queue1'

@description('Optional. The version of App Service Premium SKU to deploy. Allowed values \'PremiumV2\' or \'PremiumV3\'. Defaults to \'PremiumV3\'.')
@allowed(['PremiumV2', 'PremiumV3'])
param appServicePlanPremiumSku string = 'PremiumV3'

@description('Optional. When true will deploy a cost-optimised environment for development purposes. Note that when this param is true, the deployment is not suitable or recommended for Production environments. Default = false.')
param developmentEnvironment bool = false

param appGwSslCertKeyVaultId string

param appGwUserIdentity string

param web1Hostname string
param web2Hostname string

param appGwPipDnsLabel string = '${applicationName}-appgw'


// VARS
var functionsPlan = '${applicationName}-functions-plan'
var functionApp1 = '${applicationName}-func'
var functionContentShareName = 'function-content-share'

// Storage account name must be lowercase, alpha-numeric, and less the 24 chars in length
var functionsStorage = take(toLower(replace('${applicationName}func', '-', '')), 24)

var appServicePlan = '${applicationName}-plan'
var app1 = '${applicationName}-app1'
var app2 = '${applicationName}-app2'

var vnet = '${applicationName}-vnet'

// Static web app name
var swa = '${applicationName}-swa'

// App GW
var appGw = '${applicationName}-appgw'
var appGwBackendRequestTimeout = 31   // seconds
var appGwPublicFrontendIp = 'appGwPublicFrontendIp'
var publicHttpListener = 'publicHttpListener'
var publicHttpsListenerApp1 = 'publicHttpsListenerApp1'
var publicHttpsListenerApp2 = 'publicHttpsListenerApp2'
var app1BackendPool = 'app1BackendPool'
var app2BackendPool = 'app2BackendPool'
var backendHttpSettings = 'backendHttpSettings'
var httpRedirectConfiguration = 'httpRedirectConfiguration'
var appGwWafPolicy = '${applicationName}-appgw-waf'
var appGwPip = '${applicationName}-appgw-pip'
var appGwPublicSslCert = 'apimPublicSslCert'


var redis = '${applicationName}-cache'

var servicebus = '${applicationName}-bus'

var cogSearch = '${applicationName}-search'

var cosmos = '${applicationName}-cosmos'

var keyvault = '${applicationName}-kv'
var redisConnectionStringSecretName = 'RedisConnectionString'
var searchApiKeySecretName = 'SearchApiKey'
var sqlConnectionStringSecretName = 'SqlConnectionString'

var sql = '${applicationName}-sql'

var workspace = '${applicationName}-workspace'
var insights = '${applicationName}-insights'

var zones = ['1', '2', '3']

// Role definition Ids for managed identity role assignments
var roleDefinitionIds = {
  storage: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'                   // Storage Blob Data Contributor
  keyvault: '4633458b-17de-408a-b874-0445c86b69e6'                  // Key Vault Secrets User
  servicebus: '090c5cfd-751d-490a-894a-3ce6f1109419'                // Azure Service Bus Data Owner
  cosmosdbDataReader: '00000000-0000-0000-0000-000000000001'        // Cosmos DB Built-in Data Reader
}

// No ARM property for Azure Search URL, so have to derive it.
var searchEndpointUrl = {
  AzureCloud: 'https://${cogSearch}.search.windows.net/'
  AzureUSGovernment: 'https://${cogSearch}.search.windows.us/'
  AzureChinaCloud: 'https://${cogSearch}.search.windows.net/' // Azure China Cloud does not have Search service
}

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

var appServicePlanPremiumSkus = {
  PremiumV2: {
    name: 'P2v2'
    tier: 'PremiumV2'
    size: 'P2v2'
    family: 'Pv2'
    capacity: 3
  }
  PremiumV3: {
    name: 'P1v3'
    tier: 'PremiumV3'
    size: 'P1v3'
    family: 'Pv3'
    capacity: 3
  }
}

// VNET
//  Subnet consts
var WebappBackendSubnet = 0
var FunctionsBackendSubnet = 1
var FunctionsFrontEndSubnet = 2
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


// AZURE MONITOR - APPLICATION INSIGHTS
resource workspaceResource 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspace
  location: location
  tags: tags
}

resource insightsResource 'Microsoft.Insights/components@2020-02-02' = {
  name: insights
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResource.id
  }
}


// PRIVATE DNS ZONES
resource privateSitesDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
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

// PRIVATE ENDPOINTS

//  Each Private endpoint (PEP) is comprised of: 
//    1. Private endpoint resource, 
//    2. Private link service connection to the target resource, 
//    3. Private DNS zone group, linked to a VNet-linked private DNS Zone

resource functionApp1PepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${functionApp1}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[FunctionsFrontEndSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: functionApp1Resource.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'    // must be 'config'
          properties: {
            privateDnsZoneId: privateSitesDnsZone.id
          }
        }
      ]
    }
  }
}

resource blobStoragePepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${functionsStorage}-blob-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[StorageSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: storageResource.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateBlobsDnsZone.id
          }
        }
      ]
    }
  }
}

resource tableStoragePepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${functionsStorage}-table-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[StorageSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: storageResource.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateTablesDnsZone.id
          }
        }
      ]
    }
  }
}

resource queueStoragePepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${functionsStorage}-queue-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[StorageSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: storageResource.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateQueuesDnsZone.id
          }
        }
      ]
    }
  }
}

resource fileStoragePepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${functionsStorage}-file-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[StorageSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: storageResource.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateFilesDnsZone.id
          }
        }
      ]
    }
  }
}

resource redisPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${redis}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[RedisSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: redisResource.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateRedisDnsZone.id
          }
        }
      ]
    }
  }
}

resource servicebusPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${servicebus}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[ServiceBusSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: servicebusResource.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateServicebusDnsZone.id
          }
        }
      ]
    }
  }
}

resource searchPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${cogSearch}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[SearchSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: cogSearchResource.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateCogSearchDnsZone.id
          }
        }
      ]
    }
  }
}

resource cosmosPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${cosmos}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[CosmosSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: cosmosResource.id
          groupIds: [
            'sql'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateCosmosDnsZone.id
          }
        }
      ]
    }
  }
}

resource sqlPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${sql}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[SqlServerSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: sqlResource.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateSqlDnsZone.id
          }
        }
      ]
    }
  }
}

resource keyvaultPepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${keyvault}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetResource.properties.subnets[KeyVaultSubnet].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: keyvaultResource.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateKeyvaultDnsZone.id
          }
        }
      ]
    }
  }
}


// STORAGE ACCOUNT
resource storageResource 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: functionsStorage
  kind: 'StorageV2'
  location: location
  tags: tags
  sku: {
    name: 'Standard_ZRS'
  }
  properties:{
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    accessTier: 'Hot'
  }
  // When deploying a Function App with Bicep, a content fileshare must be explicitly created or Function App will not start.
  resource functionContentShare 'fileServices' = {
    name: 'default'
    resource share 'shares@2022-05-01' = {
      name: functionContentShareName
    }
  }
}


// PREMIUM FUNCTIONS PLAN
resource functionsPlanResource 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: functionsPlan
  location: location
  tags: tags
  kind: 'elastic'
  sku: {
    name: 'EP2'
    tier: 'ElasticPremium'
    size: 'EP2'
    family: 'EP'
    capacity: 3   // Minimum 3 instances required for zone-redundancy
  }
  properties: {
    maximumElasticWorkerCount: 10
    zoneRedundant: true  
  }
}

// APP SERVICE PLAN
resource appservicePlanResource 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlan
  location: location
  tags: tags
  kind: 'linux'
  sku: appServicePlanPremiumSkus[appServicePlanPremiumSku]
  properties: {
    reserved: true          // linux
    zoneRedundant: true
    targetWorkerCount: 3    // Minimum 3 instances required for zone-redundancy
  }
}

// WEB APPS
resource webApp1Resource 'Microsoft.Web/sites@2022-03-01' = {
  name: app1
  location: location
  tags: tags
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appservicePlanResource.id
    virtualNetworkSubnetId: vnetResource.properties.subnets[WebappBackendSubnet].id
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'dotnet|6.0'
    }
  }
  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// App settings deployed on 'existing' resource to avoid circular reference webapp <=> key vault.
resource webapp1Existing 'Microsoft.Web/sites@2022-03-01' existing = {
  name: app1
  resource webapp1ExistingConfig 'config@2020-12-01' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: insightsResource.properties.InstrumentationKey
      AZURE_SERVICE_BUS_FQ_NAMESPACE: replace(replace(servicebusResource.properties.serviceBusEndpoint, 'https://', ''), ':443/', '')
      AZURE_SERVICE_BUS_QUEUE_NAME: servicebusQueueName
      AZURE_COSMOSDB_ENDPOINT_URI: cosmosResource.properties.documentEndpoint
      AZURE_COSMOSDB_DATABASE_NAME: cosmosDatabaseName
      REDIS_CONNECTION_STRING: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${redisConnectionStringSecretName}/)'
      AZURE_SEARCH_ENDPOINT_URI: searchEndpointUrl[environment().name]
      AZURE_SEARCH_API_KEY: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${searchApiKeySecretName}/)'
    }
    dependsOn:[
      webApp1Resource
    ]
  }
}

resource webApp2Resource 'Microsoft.Web/sites@2022-03-01' = {
  name: app2
  location: location
  tags: tags
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appservicePlanResource.id
    virtualNetworkSubnetId: vnetResource.properties.subnets[WebappBackendSubnet].id
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'dotnet|6.0'
    }
  }
  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

resource webapp2Existing 'Microsoft.Web/sites@2022-03-01' existing = {
  name: app2
  resource webapp2ExistingConfig 'config@2020-12-01' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: insightsResource.properties.InstrumentationKey
    }
    dependsOn:[
      webApp2Resource
    ]
  }
}


// FUNCTION APPS
resource functionApp1Resource 'Microsoft.Web/sites@2022-03-01' = {
  name: functionApp1
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: functionsPlanResource.id
    virtualNetworkSubnetId: vnetResource.properties.subnets[FunctionsBackendSubnet].id
    siteConfig: {
      vnetRouteAllEnabled: true
      windowsFxVersion: 'dotnet|6.0'
    }
  }
  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// App settings deployed on 'existing' resource to avoid circular reference function app <=> key vault.
resource functionApp1Existing 'Microsoft.Web/sites@2022-03-01' existing = {
  name: functionApp1
  resource functionApp1ExistingConfig 'config@2020-12-01' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: insightsResource.properties.InstrumentationKey
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageResource.name};AccountKey=${storageResource.listKeys().keys[0].value}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageResource.name};AccountKey=${storageResource.listKeys().keys[0].value}'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
      WEBSITE_CONTENTOVERVNET: '1'
      WEBSITE_CONTENTSHARE: functionContentShareName
      SQL_SERVER_CONNECTION_STRING: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${sqlConnectionStringSecretName}/)'
      AZURE_SERVICE_BUS_FQ_NAMESPACE: replace(replace(servicebusResource.properties.serviceBusEndpoint, 'https://', ''), ':443/', '')
      AZURE_SERVICE_BUS_QUEUE_NAME: servicebusQueueName
    }
    dependsOn:[
      functionApp1Resource
    ]
  }
}


// STATIC WEB APP
resource staticWebAppResource 'Microsoft.Web/staticSites@2022-03-01' = {
  name: swa
  location: staticWebAppLocation
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    repositoryUrl: 'https://github.com/staticwebdev/vanilla-basic'
    branch: 'main'
  }
}

// APP GW
resource pipResource 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: appGwPip
  location: location
  tags: tags
  zones: zones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: appGwPipDnsLabel
    }
    ddosSettings: {
      protectionMode: developmentEnvironment ? 'Disabled' : 'Enabled'
    }
  }
}

resource appGWResource 'Microsoft.Network/applicationGateways@2022-05-01' = {
  name: appGw
  location: location
  tags: tags
  zones: zones
  identity:{
    type:'UserAssigned'
    userAssignedIdentities: {
      '${appGwUserIdentity}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: developmentEnvironment ? 1 : 3
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: vnetResource.properties.subnets[AppGwSubnet].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipResource.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: app1BackendPool
        properties: {
          backendAddresses:[
            {
              fqdn: webApp1Resource.properties.defaultHostName
            }
          ]
        }
      }
      {
        name: app2BackendPool
        properties: {
          backendAddresses:[
            {
              fqdn: webApp2Resource.properties.defaultHostName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettings
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: appGwBackendRequestTimeout
          //TODO: Use well known CA certificate = Yes
        }
      }
    ]
    sslCertificates:[
      {
        name: appGwPublicSslCert
        properties: {
          keyVaultSecretId: appGwSslCertKeyVaultId
        }
      }
    ]
    httpListeners: [
      {
        name: publicHttpListener
        properties: {
          firewallPolicy: {
            id: appGwWafPolicyResource.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw, appGwPublicFrontendIp)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
      {
        name: publicHttpsListenerApp1
        properties: {
          firewallPolicy: {
            id: appGwWafPolicyResource.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw, appGwPublicFrontendIp)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw, 'port_443')
          }
          protocol: 'Https'
          sslCertificate:{
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGw, appGwPublicSslCert)
          }
          hostNames: [web1Hostname]
        }
      }
      {
        name: publicHttpsListenerApp2
        properties: {
          firewallPolicy: {
            id: appGwWafPolicyResource.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw, appGwPublicFrontendIp)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw, 'port_443')
          }
          protocol: 'Https'
          sslCertificate:{
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGw, appGwPublicSslCert)
          }
          hostNames: [web2Hostname]
        }
      }
    ]
    redirectConfigurations:[
      {
        // Redirect HTTP => HTTPS
        name: httpRedirectConfiguration
        properties:{
          includePath: true
          includeQueryString: true
          redirectType: 'Permanent'
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw, publicHttpsListenerApp1)
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpRedirectRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw, publicHttpListener)
          }
          redirectConfiguration:{
            id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', appGw, httpRedirectConfiguration)
          }
        }
      }
      {
        name: 'web1RoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 110
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw, publicHttpsListenerApp1)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGw, app1BackendPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGw, backendHttpSettings)
          }
        }
      }
      {
        name: 'web2RoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 120
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw, publicHttpsListenerApp2)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGw, app2BackendPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGw, backendHttpSettings)
          }
        }
      }
    ]
    enableHttp2: true
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    firewallPolicy: {
      id: appGwWafPolicyResource.id
    }
  }
}

resource appGwWafPolicyResource 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-05-01' = {
  name: appGwWafPolicy
  location: location
  tags: tags
  properties: {
    customRules: [
    ]
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
      ]
    }
  }
}


// REDIS PREMIUM
resource redisResource 'Microsoft.Cache/redis@2022-05-01' = {
  name: redis
  location: location
  tags: tags
  zones: ['1', '2', '3']
  properties: {
    sku: {
      capacity: 1
      family: 'P'
      name: 'Premium'
    }
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    replicasPerMaster: 2
    replicasPerPrimary: 2
  }
}


// SERVICE BUS PREMIUM
resource servicebusResource 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: servicebus
  location: location
  tags: tags
  sku: {
    name: 'Premium'
    capacity: 1
    tier: 'Premium'
  }
  properties:{
    zoneRedundant: true
  }
  resource queue1 'queues@2021-11-01' = {
    name: servicebusQueueName
  }
}


// COG SEARCH
resource cogSearchResource 'Microsoft.Search/searchServices@2020-08-01' = {
  name: cogSearch
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 3
    publicNetworkAccess: 'disabled'
  }
}


// COSMOS DB
resource cosmosResource 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: cosmos
  location: location
  tags: tags

  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        isZoneRedundant: true
        failoverPriority: 0
      }
    ]
    publicNetworkAccess: 'Disabled'
    backupPolicy:{
      type: 'Continuous'
    }
  }
  resource database 'sqlDatabases@2022-05-15' = {
    name: cosmosDatabaseName
    location: location
    properties: {
      resource: {
        id: cosmosDatabaseName
      }
      options:{
        throughput: 400
      }
    }
    resource container 'containers@2022-05-15' = {
      name: cosmosContainerName
      location: location
      properties: {
        resource: {
          id: cosmosContainerName
          partitionKey: {
            kind: 'Hash'
            paths: cosmosPartitionKeys
          }
        }
      }
    }
  }
}


// KEY VAULT
resource keyvaultResource 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyvault
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    publicNetworkAccess: 'disabled'
    accessPolicies: [
      {
        objectId: webApp1Resource.identity.principalId
        tenantId: webApp1Resource.identity.tenantId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
      {
        objectId: functionApp1Resource.identity.principalId
        tenantId: functionApp1Resource.identity.tenantId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
  }
  resource redisSecretResource 'secrets@2022-07-01' = {
    name: redisConnectionStringSecretName
    properties: {
      value: '${redisResource.properties.hostName}:6380,password=${redisResource.listKeys().primaryKey},ssl=True,abortConnect=False'
    }
  }
  resource sqlSecretResource 'secrets@2022-07-01' = {
    name: sqlConnectionStringSecretName
    properties: {
      value: 'Server=tcp:${sqlResource.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdmin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }
  resource searchSecretResource 'secrets@2022-07-01' = {
    name: searchApiKeySecretName
    properties: {
      value: cogSearchResource.listAdminKeys().primaryKey
    }
  }
}


// SQL
resource sqlResource 'Microsoft.Sql/servers@2021-11-01' = {
  name: sql
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdmin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
  }
  resource db 'databases@2021-11-01' = {
    name: sqlDatabaseName
    location: location
    tags: tags
    sku: {
      name: 'P1'
      tier: 'Premium'
    }
    properties: {
      zoneRedundant: true
    }
  }
}


// ROLE ASSIGNMENTS

// Assigns Function App 1 data role to Storage Account
resource functionApp1RoleAssignmentStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // * Name of a role assignment must be a GUID and must be unique within the Subscription.
  name: guid(storageResource.id, functionApp1Resource.id, roleDefinitionIds.storage)
  scope: storageResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.storage)
    principalId: functionApp1Resource.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Function App 1 data role to Service Bus
resource functionApp1RoleAssignmentServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicebusResource.id, functionApp1Resource.id, roleDefinitionIds.servicebus)
  scope: servicebusResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.servicebus)
    principalId: functionApp1Resource.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Web App data role to Service Bus
resource webApp1RoleAssignmentServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicebusResource.id, webApp1Resource.id, roleDefinitionIds.servicebus)
  scope: servicebusResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.servicebus)
    principalId: webApp1Resource.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Web App reader role to Key Vault
resource webAppRoleAssignmentKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyvaultResource.id, webApp1Resource.id, roleDefinitionIds.keyvault)
  scope: keyvaultResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyvault)
    principalId: webApp1Resource.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos Data plane RBAC role assignment
resource webAppRoleAssignmentCosmosDbSql 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  name: '${cosmos}/${guid(roleDefinitionIds.cosmosdbDataReader, webApp1Resource.id, cosmosResource.id)}'
  properties: {
    roleDefinitionId: '${cosmosResource.id}/sqlRoleDefinitions/${roleDefinitionIds.cosmosdbDataReader}'
    principalId: webApp1Resource.identity.principalId
    scope: cosmosResource.id
  }
}

// Outputs
output appGwHostname string = pipResource.properties.dnsSettings.fqdn
output applicationName string = applicationName
output environmentOutput object = environment()
output functionAppPlanName string = functionsPlan
output functionAppHostname string = functionApp1Resource.properties.defaultHostName
output functionAppName string = functionApp1
output insightsInstrumentationKey string = insightsResource.properties.InstrumentationKey
output staticWebAppHostname string = staticWebAppResource.properties.defaultHostname
output webappPlanName string = appServicePlan
output webapp1Name string = app1
output webapp2Name string = app2
output webappHostname string = webApp1Resource.properties.defaultHostName
