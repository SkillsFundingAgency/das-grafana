<#
.SYNOPSIS
Create a Grafana organisation.

.DESCRIPTION
Create a Grafana organisation if it doesn't exist.

.PARAMETER GrafanaBaseUri
The base uri of the grafana instance.

.PARAMETER OrgNames
An array of names that will be added to the organisation.  Rerunning the script with a different value will add new organisations, it will not update the organisation name.

.PARAMETER Password
The password of a Grafana admin account

.PARAMETER Username
The username of a Grafana admin account

.EXAMPLE
./New-GrafanaOrg.ps1 -GrafanaBaseUri https://foo.grafana.gov.uk -OrgName "Foo Service", "Bar Service" -Password not-a-real-password -Username admin
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]    
    [string]$GrafanaBaseUri,
    [Parameter(Mandatory = $true)]
    [string[]]$OrgNames,
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
$Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

$ExistingOrgs = Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs -Method GET -Headers $Headers
foreach ($OrgName in $OrgNames) {
    if($ExistingOrg = $ExistingOrgs | Where-Object { $_.name -eq $OrgName }) {
        Write-Output "Organisation $OrgName with id $($ExistingOrg.id) already exists."
    }
    else {
        Write-Output "Organisation $OrgName doesn't exist, creating ..."
        $Body = @{
            name = $OrgName
        }
        Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs -Method POST -Body $Body -Headers $Headers
    }
}

