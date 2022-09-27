$ErrorActionPreference = 'Stop'

$rg = $env:AZURE_RESOURCE_GROUP
if ($rg -eq $null ) { throw 'Environment variable AZURE_RESOURCE_GROUP must be set' }

az group create -n $rg -l westus3

az deployment group create -g $rg --template-file ../bicep/main.bicep --parameters staticWebAppLocation=westus2
