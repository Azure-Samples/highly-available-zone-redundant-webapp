$rg = 'hazrweb3-wus3-rg'            # <-- Name of Resource Group to deploy to.
$certKeyVault = 'fscale-kv'         # <-- Name of Key Vault that stores TLS cert. Does not need to be in the same resource group.
$certSecretId = 'hazr-fscale-nz'    # <-- Secret Id of the certificate
$appGwSslCertKeyVaultId = "https://$certKeyVault.vault.azure.net/secrets/$certSecretId"
$developmentEnvironment = $true     # <-- Set to false for Production deployment
$zone = 'fscale.nz'
$zoneRG = 'fscale-wus3-rg'
$web1Hostname = 'hazr-web1'
$web2Hostname = 'hazr-web2'

az group create --name $rg --location westus3

$identity = ( az identity create --name hazripaas-appgw-user --resource-group $rg -o json | ConvertFrom-Json )

az keyvault set-policy -n $certKeyVault --secret-permissions get --object-id $identity.principalId

$deployment = ( 
az deployment group create --resource-group $rg --template-file ../bicep/main-appgw.bicep --parameters `
    "developmentEnvironment=$developmentEnvironment" `
    "appGwSslCertKeyVaultId=$appGwSslCertKeyVaultId" `
    "appGwUserIdentity=$($identity.id)" `
    "web1Hostname=$web1Hostname.$zone" `
    "web2Hostname=$web2Hostname.$zone" `
    "staticWebAppLocation=westus2" `
    | ConvertFrom-Json )

$deployment

if ($null -eq $deployment) {
    throw 'Deployment failed'
}

# Get appGwHostname and set DNS CNAMEs
az network dns record-set cname set-record -g $zoneRG -z $zone `
     -n $web1Hostname -c $deployment.properties.outputs.appGwHostname.value

az network dns record-set cname set-record -g $zoneRG -z $zone `
     -n $web2Hostname -c $deployment.properties.outputs.appGwHostname.value

# Publish apps
az webapp config container set -n $deployment.properties.outputs.webapp1Name.value -g $rg -i daniellarsennz/helloaspdotnetcore
az webapp config container set -n $deployment.properties.outputs.webapp2Name.value -g $rg -i daniellarsennz/helloaspdotnetcore

start "https://$web1Hostname.$zone"
start "https://$web2Hostname.$zone"




#TODO
# https://learn.microsoft.com/en-us/azure/application-gateway/certificates-for-backend-authentication
# https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-end-to-end-ssl-powershell
