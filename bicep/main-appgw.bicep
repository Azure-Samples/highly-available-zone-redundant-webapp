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

// NETWORK
module networkModule 'modules/network.bicep' = {
  name: 'network'
  params: {
    applicationName: applicationName
    location: location
    tags: tags
  }
}

// PRIVATE ENDPOINTS
module functionApp1PepModule 'modules/pep.bicep' = {
  name: 'functionApp1PepModule'
  params: {
    resourceName: functionsModule.outputs.functionAppName
    resourceId: functionsModule.outputs.functionAppResourceId
    location: location
    tags: tags
    groupId: 'sites'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.functions
    subnetId: networkModule.outputs.subnetIds.functionsFrontend
  }
}

module blobStoragePepModule 'modules/pep.bicep' = {
  name: 'blobStoragePepModule'
  params: {
    resourceName: functionsModule.outputs.functionsStorageName
    resourceId: functionsModule.outputs.functionsStorageResourceId
    location: location
    tags: tags
    groupId: 'blob'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.blobs
    subnetId: networkModule.outputs.subnetIds.storage
  }
}

module tableStoragePepModule 'modules/pep.bicep' = {
  name: 'tableStoragePepModule'
  params: {
    resourceName: functionsModule.outputs.functionsStorageName
    resourceId: functionsModule.outputs.functionsStorageResourceId
    location: location
    tags: tags
    groupId: 'table'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.tables
    subnetId: networkModule.outputs.subnetIds.storage
  }
}

module queueStoragePepModule 'modules/pep.bicep' = {
  name: 'queueStoragePepModule'
  params: {
    resourceName: functionsModule.outputs.functionsStorageName
    resourceId: functionsModule.outputs.functionsStorageResourceId
    location: location
    tags: tags
    groupId: 'queue'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.queues
    subnetId: networkModule.outputs.subnetIds.storage
  }
}

module fileStoragePepModule 'modules/pep.bicep' = {
  name: 'fileStoragePepModule'
  params: {
    resourceName: functionsModule.outputs.functionsStorageName
    resourceId: functionsModule.outputs.functionsStorageResourceId
    location: location
    tags: tags
    groupId: 'file'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.files
    subnetId: networkModule.outputs.subnetIds.storage
  }
}

module redisPepModule 'modules/pep.bicep' = {
  name: 'redisStoragePepModule'
  params: {
    resourceName: redisResource.name
    resourceId: redisResource.id
    location: location
    tags: tags
    groupId: 'redisCache'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.redis
    subnetId: networkModule.outputs.subnetIds.redis
  }
}

module servicebusPepModule 'modules/pep.bicep' = {
  name: 'servicebusStoragePepModule'
  params: {
    resourceName: servicebusResource.name
    resourceId: servicebusResource.id
    location: location
    tags: tags
    groupId: 'namespace'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.serviceBus
    subnetId: networkModule.outputs.subnetIds.serviceBus
  }
}

module searchPepModule 'modules/pep.bicep' = {
  name: 'searchPepModule'
  params: {
    resourceName: cogSearchResource.name
    resourceId: cogSearchResource.id
    location: location
    tags: tags
    groupId: 'searchService'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.search
    subnetId: networkModule.outputs.subnetIds.search
  }
}

module cosmosPepModule 'modules/pep.bicep' = {
  name: 'cosmosPepModule'
  params: {
    resourceName: cosmosResource.name
    resourceId: cosmosResource.id
    location: location
    tags: tags
    groupId: 'sql'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.cosmos
    subnetId: networkModule.outputs.subnetIds.cosmos
  }
}

module sqlPepModule 'modules/pep.bicep' = {
  name: 'sqlPepModule'
  params: {
    resourceName: sqlResource.name
    resourceId: sqlResource.id
    location: location
    tags: tags
    groupId: 'sqlServer'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.sqlServer
    subnetId: networkModule.outputs.subnetIds.sqlServer
  }
}

module keyvaultPepModule 'modules/pep.bicep' = {
  name: 'keyvaultPepModule'
  params: {
    resourceName: keyvaultResource.name
    resourceId: keyvaultResource.id
    location: location
    tags: tags
    groupId: 'vault'
    privateDnsZoneId: networkModule.outputs.privateDnsZoneIds.keyvault
    subnetId: networkModule.outputs.subnetIds.keyvault
  }
}

// APP SERVICES
module appServicesModule 'modules/appServices.bicep' = {
  name: 'appServicesModule'
  params: {
    applicationName: applicationName
    location: location
    tags: tags
    vnetSubnetId: networkModule.outputs.subnetIds.appServices
    appServicePlanPremiumSku: appServicePlanPremiumSku
    developmentEnvironment: developmentEnvironment
    appSettings: {
      APPINSIGHTS_INSTRUMENTATIONKEY: insightsResource.properties.InstrumentationKey
      AZURE_SERVICE_BUS_FQ_NAMESPACE: replace(replace(servicebusResource.properties.serviceBusEndpoint, 'https://', ''), ':443/', '')
      AZURE_SERVICE_BUS_QUEUE_NAME: servicebusQueueName
      AZURE_COSMOSDB_ENDPOINT_URI: cosmosResource.properties.documentEndpoint
      AZURE_COSMOSDB_DATABASE_NAME: cosmosDatabaseName
      REDIS_CONNECTION_STRING: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${redisConnectionStringSecretName}/)'
      AZURE_SEARCH_ENDPOINT_URI: searchEndpointUrl[environment().name]
      AZURE_SEARCH_API_KEY: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${searchApiKeySecretName}/)'
    }
  }
}


// FUNCTIONS 
module functionsModule 'modules/functions.bicep' = {
  name: 'functionsModule'
  params: {
    applicationName: applicationName
    location: location
    tags: tags
    vnetSubnetId: networkModule.outputs.subnetIds.functionsBackend
    developmentEnvironment: developmentEnvironment
    appSettings: {
      APPINSIGHTS_INSTRUMENTATIONKEY: insightsResource.properties.InstrumentationKey
      SQL_SERVER_CONNECTION_STRING: '@Microsoft.KeyVault(SecretUri=${keyvaultResource.properties.vaultUri}secrets/${sqlConnectionStringSecretName}/)'
      AZURE_SERVICE_BUS_FQ_NAMESPACE: replace(replace(servicebusResource.properties.serviceBusEndpoint, 'https://', ''), ':443/', '')
      AZURE_SERVICE_BUS_QUEUE_NAME: servicebusQueueName
    }
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
            id: networkModule.outputs.subnetIds.appGateway
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
              fqdn: appServicesModule.outputs.webapp1Hostname
            }
          ]
        }
      }
      {
        name: app2BackendPool
        properties: {
          backendAddresses:[
            {
              fqdn: appServicesModule.outputs.webapp2Hostname
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
    replicasPerMaster: developmentEnvironment ? 2 : 0
    replicasPerPrimary: developmentEnvironment ? 2 : 0
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
    replicaCount: developmentEnvironment ? 1 : 3
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
    accessPolicies: []
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

resource keyVaultPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-11-01' = {
  parent: keyvaultResource
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: appServicesModule.outputs.webapp1Identity.principalId
        tenantId: appServicesModule.outputs.webapp1Identity.tenantId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
      {
        objectId: functionsModule.outputs.functionAppIdentity.principalId
        tenantId: functionsModule.outputs.functionAppIdentity.tenantId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
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
// Assigns Function App 1 data role to Service Bus
resource functionApp1RoleAssignmentServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicebusResource.id, functionsModule.name, '1', roleDefinitionIds.servicebus)
  scope: servicebusResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.servicebus)
    principalId: functionsModule.outputs.functionAppIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Web App data role to Service Bus
resource webApp1RoleAssignmentServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicebusResource.id, appServicesModule.name, '1', roleDefinitionIds.servicebus)
  scope: servicebusResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.servicebus)
    principalId: appServicesModule.outputs.webapp1Identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Web App reader role to Key Vault
resource webAppRoleAssignmentKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyvaultResource.id, appServicesModule.name, '1', roleDefinitionIds.keyvault)
  scope: keyvaultResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyvault)
    principalId: appServicesModule.outputs.webapp1Identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos Data plane RBAC role assignment
resource webAppRoleAssignmentCosmosDbSql 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  parent: cosmosResource
  name: guid(roleDefinitionIds.cosmosdbDataReader, appServicesModule.name, '1', cosmosResource.id)
  properties: {
    roleDefinitionId: '${cosmosResource.id}/sqlRoleDefinitions/${roleDefinitionIds.cosmosdbDataReader}'
    principalId: appServicesModule.outputs.webapp1Identity.principalId
    scope: cosmosResource.id
  }
}


// Outputs
output appGwHostname string = pipResource.properties.dnsSettings.fqdn
output applicationName string = applicationName
output environmentOutput object = environment()
output insightsInstrumentationKey string = insightsResource.properties.InstrumentationKey
output staticWebAppHostname string = staticWebAppResource.properties.defaultHostname
output webapp1Name string = appServicesModule.outputs.webapp1Name
output webapp2Name string = appServicesModule.outputs.webapp2Name
