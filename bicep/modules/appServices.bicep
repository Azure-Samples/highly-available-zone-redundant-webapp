param applicationName string
param location string
param tags object
param appSettings object
param vnetSubnetId string
param appServicePlanPremiumSku string = 'PremiumV3'
param developmentEnvironment bool

// VARS
var appServicePlan = '${applicationName}-plan'
var app1 = '${applicationName}-app1'
var app2 = '${applicationName}-app2'

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
    virtualNetworkSubnetId: vnetSubnetId
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
    properties: appSettings
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
    virtualNetworkSubnetId: vnetSubnetId
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
    properties: appSettings
    dependsOn:[
      webApp2Resource
    ]
  }
}

output webappPlanName string = appServicePlan
output webapp1Name string = app1
output webapp1Hostname string = webApp1Resource.properties.defaultHostName
output webapp1Identity object = webApp1Resource.identity
output webapp1ResourceId string = webApp1Resource.id
output webapp2Name string = app2
output webapp2Hostname string = webApp2Resource.properties.defaultHostName
output webapp2Identity object = webApp2Resource.identity
output webapp2ResourceId string = webApp2Resource.id
