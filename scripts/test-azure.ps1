$ErrorActionPreference = 'Stop'

$rg = $env:AZURE_RESOURCE_GROUP
if ($rg -eq $null ) { throw 'Environment variable AZURE_RESOURCE_GROUP must be set' }

$outputs = ( az deployment group show -g $rg -n main --query properties.outputs | ConvertFrom-Json )
if ($outputs -eq $null ) { throw 'main deployment outputs is null.' }


# Test URLs
$webappUrl = "https://$($outputs.webappHostname.value)/health"
$functionappUrl = "https://$($outputs.functionApp2Hostname.value)/api/health"
$frontdoorWebappUrl = "https://$($outputs.frontDoorApiHostname.value)/health"

$ErrorActionPreference = 'Continue'

$i = 0
while($true)
{ 
    $i++   

    try {
        Write-Host "Attempt $i : GET $functionappUrl"
        Invoke-RestMethod $functionappUrl -TimeoutSec 40
    }
    catch {
        Write-Warning "Attempt $i : $($_.ErrorDetails.Message)"
    }

    try {
        Write-Host "Waiting 10 seconds..."
        Start-Sleep -Seconds 10

        Write-Host "Attempt $i : GET $webappUrl"
        Invoke-RestMethod $webappUrl -TimeoutSec 40
    }
    catch {
        Write-Warning "Attempt $i : $($_.ErrorDetails.Message)"
    }

    try {
        Write-Host "Attempt $i : GET $frontdoorWebappUrl"
        Invoke-RestMethod $frontdoorWebappUrl -TimeoutSec 40
    }
    catch {
        Write-Warning "Attempt $i : $($_.ErrorDetails.Message)"
    }
}
