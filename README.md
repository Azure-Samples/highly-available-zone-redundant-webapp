---
name: Highly available zone-redundant web application
page_type: sample
languages:
- bicep
products:
- azure
- azure-app-service
- azure-functions
- azure-front-door
- azure-cache-redis
- azure-cognitive-search
- azure-search
- azure-cosmos-db
- azure-key-vault
- azure-blob-storage
- azure-private-link
- azure-service-bus
- azure-sql-database
---

# Highly available zone-redundant web application

This is the deployment template for the Azure architecture center reference architecture: "Highly available zone-redundant web application".

## Getting started

```bash
az group create -n zr-ha-webapp-rg -l westus2
az deployment group create -g zr-ha-webapp-rg --template-file ./bicep/main.bicep
```

## Bicep parameters

| param | Description | Default value |
| -- | -- | -- |
| `applicationName` | Optional. A name that will be prepended to all deployed resources. | An alphanumeric id that is unique to the resource group. |
| `location` | Optional. The Azure region (location) to deploy to. Must be a region that supports availability zones. | Resource group location. |
| `staticWebAppsLocation` | Optional. The Azure region (location) to deploy Static Web Apps to. Even though Static Web Apps is a non-regional resource, a location must be chosen from a limited subset of region. | The value of the `location` parameter, or the resource group location. |
| `sqlAdminPassword` | Optional. A password for the Azure SQL server admin user. | Defaults to a new GUID. |