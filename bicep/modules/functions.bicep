param applicationName string
param location string
param tags object
param appSettings object
param vnetSubnetId string
param developmentEnvironment bool = false


// VARS
var functionsPlan = '${applicationName}-functions-plan'
var functionApp1 = '${applicationName}-func'
var functionContentShareName = 'function-content-share'

// Storage account name must be lowercase, alpha-numeric, and less the 24 chars in length
var functionsStorage = take(toLower(replace('${applicationName}func', '-', '')), 24)

// Role definition Ids for managed identity role assignments
var roleDefinitionIds = {
  storage: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'                   // Storage Blob Data Contributor
  keyvault: '4633458b-17de-408a-b874-0445c86b69e6'                  // Key Vault Secrets User
  servicebus: '090c5cfd-751d-490a-894a-3ce6f1109419'                // Azure Service Bus Data Owner
  cosmosdbDataReader: '00000000-0000-0000-0000-000000000001'        // Cosmos DB Built-in Data Reader
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
    capacity: developmentEnvironment ? 3 : 1    // Minimum 3 instances required for zone-redundancy
  }
  properties: {
    maximumElasticWorkerCount: 6
    zoneRedundant: !developmentEnvironment  
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
    virtualNetworkSubnetId: vnetSubnetId
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
    properties: union(appSettings, {
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageResource.name};AccountKey=${storageResource.listKeys().keys[0].value}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageResource.name};AccountKey=${storageResource.listKeys().keys[0].value}'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
      WEBSITE_CONTENTOVERVNET: '1'
      WEBSITE_CONTENTSHARE: functionContentShareName
    })
    dependsOn:[
      functionApp1Resource
    ]
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

output functionAppPlanName string = functionsPlan
output functionAppHostname string = functionApp1Resource.properties.defaultHostName
output functionAppName string = functionApp1
output functionAppResourceId string = functionApp1Resource.id
output functionAppIdentity object = functionApp1Resource.identity
output functionsStorageName string = storageResource.name
output functionsStorageResourceId string = storageResource.id
