$ErrorActionPreference = 'Stop'

$rg = $env:AZURE_RESOURCE_GROUP

if ($rg -eq $null ) { throw 'Environment variable AZURE_RESOURCE_GROUP must be set' }

$properties = ( az deployment group show -g $rg -n main --query properties | ConvertFrom-Json )

if ($properties.outputs -eq $null ) { 
    $properties
    throw 'main deployment outputs is null.' 
}

$outputs = $properties.outputs

# App Services
$outputs.webappName.value
#az webapp config container set --name $outputs.webappName.value -g $rg -i daniellarsennz/healthchecksaspnet
Invoke-WebRequest -Uri https://github.com/DanielLarsenNZ/HealthChecksDotNet/releases/download/v1.0.1/webapp_deploy.zip -OutFile _webapp_deploy.zip
az webapp deployment source config-zip -g $rg -n $outputs.webappName.value --src _webapp_deploy.zip
az webapp config appsettings set --name $outputs.webappName.value -g $rg --settings "HTTPS_ENDPOINT_URLS=https://$($outputs.functionAppHostname.value)/api/health"

# Functions
#az functionapp config container set -i daniellarsennz/healthchecksazurefunctions -n $outputs.functionAppName.value -g $rg
Invoke-WebRequest -Uri https://github.com/DanielLarsenNZ/HealthChecksDotNet/releases/download/v1.0.1/functionapp_deploy.zip -OutFile _functionapp_deploy.zip
az webapp deployment source config-zip -g $rg -n $outputs.functionAppName.value --src _functionapp_deploy.zip
#az functionapp config appsettings set -n $outputs.functionAppName.value -g $rg --settings "FUNCTIONS_WORKER_RUNTIME=dotnet-isolated"
    
#az functionapp config container set -i daniellarsennz/healthchecksazurefunctions -n $outputs.functionApp2Name.value -g $rg
az webapp deployment source config-zip -g $rg -n $outputs.functionApp2Name.value --src _functionapp_deploy.zip
#az functionapp config appsettings set -n $outputs.functionApp2Name.value -g $rg --settings "FUNCTIONS_WORKER_RUNTIME=dotnet-isolated"
