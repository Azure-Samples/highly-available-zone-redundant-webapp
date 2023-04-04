param resourceName string
param resourceId string
param location string
param tags object
param subnetId string
param groupId string
param privateDnsZoneId string

// PRIVATE ENDPOINTS

//  Each Private endpoint (PEP) is comprised of: 
//    1. Private endpoint resource, 
//    2. Private link service connection to the target resource, 
//    3. Private DNS zone group, linked to a VNet-linked private DNS Zone

resource functionApp1PepResource 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: '${resourceName}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: resourceId
          groupIds: [
            groupId
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
            privateDnsZoneId: privateDnsZoneId
          }
        }
      ]
    }
  }
}
