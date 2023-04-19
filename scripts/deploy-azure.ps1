$PUBLISH_APPS = $true

$rg = 'hazrweb11-wus3-rg'               # <-- Name of Resource Group to deploy to.
$certKeyVault = 'fscale-kv'             # <-- Name of Key Vault that stores TLS cert. Does not need to be in the same resource group.
$certSecretId = 'hazr-fscale-nz'        # <-- Secret Id of the certificate
$appGwSslCertKeyVaultId = "https://$certKeyVault.vault.azure.net/secrets/$certSecretId"
$developmentEnvironment = $true         # <-- Set to false for Production deployment
$zone = 'fscale.nz'
$zoneRG = 'fscale-wus3-rg'
$webapp1Hostname = 'hazr-web1'
$webapp2Hostname = 'hazr-web2'
$ttl = 60   # seconds. DNS TTL. Use 60 seconds for development/testing. Use 3600 seconds for production.

if ($CREATE_RG) {
    az group create --name $rg --location westus3
}

$identity = ( az identity create --name hazripaas-appgw-user --resource-group $rg -o json | ConvertFrom-Json )

if ($CONFIGURE_KEYVAULT_POLICY) {    
    az keyvault set-policy -n $certKeyVault --secret-permissions get --object-id $identity.principalId
}

$deployment = ( 
    az deployment group create --resource-group $rg --template-file ../bicep/main-appgw.bicep --parameters `
        "developmentEnvironment=$developmentEnvironment" `
        "appGwSslCertKeyVaultId=$appGwSslCertKeyVaultId" `
        "appGwUserIdentity=$($identity.id)" `
        "webapp1Hostname=$webapp1Hostname.$zone" `
        "webapp2Hostname=$webapp2Hostname.$zone" `
        "staticWebAppLocation=westus2" `
        | ConvertFrom-Json )
    
$deployment

if ($null -eq $deployment) {
    throw 'Deployment failed'
}

$webapp1Name = $deployment.properties.outputs.webapp1Name.value
$webapp2Name = $deployment.properties.outputs.webapp2Name.value
$appGwHostname = $deployment.properties.outputs.appGwHostname.value

if ($CONFIG_WEBAPPS_TLS)
{
    # Point DNS CNAMEs to Web Apps
    az network dns record-set cname set-record -g $zoneRG -z $zone -n $webapp1Hostname -c $deployment.properties.outputs.webapp1Hostname.value --ttl $ttl
    az network dns record-set cname set-record -g $zoneRG -z $zone -n $webapp2Hostname -c $deployment.properties.outputs.webapp2Hostname.value --ttl $ttl

    # Add Web App DNS validation TXT records
    $webapp1 = ( az webapp show -n $webapp1Name -g $rg | ConvertFrom-Json )
    $webapp2 = ( az webapp show -n $webapp2Name -g $rg | ConvertFrom-Json )

    az network dns record-set txt add-record -g $zoneRG -z "$zone" -n "asuid.$webapp1Hostname" -v $webapp1.customDomainVerificationId
    az network dns record-set txt add-record -g $zoneRG -z "$zone" -n "asuid.$webapp2Hostname" -v $webapp2.customDomainVerificationId

    # Config webapp custom domain names
    az webapp config hostname add --webapp-name $webapp1Name -g $rg --hostname "$webapp1Hostname.$zone"
    az webapp config hostname add --webapp-name $webapp2Name -g $rg --hostname "$webapp2Hostname.$zone"

    # Create Managed TLS certs
    az webapp config ssl create --hostname "$webapp1Hostname.$zone" -n $webapp1Name -g $rg 
    az webapp config ssl create --hostname "$webapp2Hostname.$zone" -n $webapp2Name -g $rg 

    # Bind the certs to the Web Apps
    $cert1 = ( az webapp config ssl show --certificate-name $webapp1Fqdn -g $rg | ConvertFrom-Json )
    $cert2 = ( az webapp config ssl show --certificate-name $webapp2Fqdn -g $rg | ConvertFrom-Json )
    
    if ($null -eq $cert1.thumbprint -or '' -eq $cert1.thumbprint) {
        $cert1
        throw 'Cert1 thumbprint is null or empty.'
    }
    
    az webapp config ssl bind --certificate-thumbprint $cert1.thumbprint --ssl-type SNI -n $webapp1Name -g $rg
    
    if ($null -eq $cert2.thumbprint -or '' -eq $cert2.thumbprint) {
        $cert2
        throw 'Cert2 thumbprint is null or empty.'
    }
    
    az webapp config ssl bind --certificate-thumbprint $cert2.thumbprint --ssl-type SNI -n $webapp2Name -g $rg
}

if ($CONFIG_APPGW_DNS) {
    # Point DNS CNAMEs to App GW
    az network dns record-set cname set-record -g $zoneRG -z $zone -n $webapp1Hostname -c $appGwHostname --ttl $ttl
    az network dns record-set cname set-record -g $zoneRG -z $zone -n $webapp2Hostname -c $appGwHostname --ttl $ttl
}

if ($PUBLISH_APPS) {
    # Publish apps
    az webapp config container set -n $webapp1Name -g $rg -i daniellarsennz/helloaspdotnetcore
    az webapp config container set -n $webapp2Name -g $rg -i daniellarsennz/helloaspdotnetcore

    start "https://$webapp1Hostname.$zone"
    start "https://$webapp2Hostname.$zone"
}


#TODO
# https://learn.microsoft.com/en-us/azure/application-gateway/certificates-for-backend-authentication
# https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-end-to-end-ssl-powershell
