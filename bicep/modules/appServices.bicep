param applicationName string
param location string
param tags object
param webappName string
param appSettings object
param vnetSubnetId string
param appServicePlanPremiumSku string = 'PremiumV3'
param developmentEnvironment bool


// VARS
var appServicePlan = '${applicationName}-plan'

var appServicePlanPremiumSkus = {
  PremiumV2: {
    name: 'P2v2'
    tier: 'PremiumV2'
    size: 'P2v2'
    family: 'Pv2'
    capacity: developmentEnvironment ? 1 : 3
  }
  PremiumV3: {
    name: 'P1v3'
    tier: 'PremiumV3'
    size: 'P1v3'
    family: 'Pv3'
    capacity: developmentEnvironment ? 1 : 3
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
    zoneRedundant: !developmentEnvironment
    targetWorkerCount: developmentEnvironment ? 1 : 3    // Minimum 3 instances required for zone-redundancy
  }
}


// WEB APP
resource webappResource 'Microsoft.Web/sites@2022-03-01' = {
  name: webappName
  location: location
  tags: tags
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appservicePlanResource.id
    virtualNetworkSubnetId: vnetSubnetId
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: 'dotnet|6.0'
    }
  }

  resource config 'config@2022-03-01' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}


// App settings deployed on 'existing' resource to avoid circular reference webapp <=> key vault.
resource webappExisting 'Microsoft.Web/sites@2022-03-01' existing = {
  name: webappName
  resource webappExistingConfig 'config@2020-12-01' = {
    name: 'appsettings'
    properties: appSettings
    dependsOn:[
      webappResource
    ]
  }
}


output webappName string = webappName
output webappPlanName string = appServicePlan
output webappHostname string = webappResource.properties.defaultHostName
output webappIdentity object = webappResource.identity
output webappResourceId string = webappResource.id
