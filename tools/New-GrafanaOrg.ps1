<#
.SYNOPSIS
Create a Grafana organisation.

.DESCRIPTION
Create a Grafana organisation if it doesn't exist.

.PARAMETER GrafanaBaseUri
The base uri of the grafana instance.

.PARAMETER OrgId
The Id of the organisation to create, used to check if the organisation already exists

.PARAMETER OrgName
The Name of the organisation.  Rerunning the script with a different value will not update the organisation name.

.PARAMETER Password
The password of a Grafana admin account

.PARAMETER Username
The username of a Grafana admin account

.EXAMPLE
./New-GrafanaOrg.ps1 -GrafanaBaseUri https://foo.grafana.gov.uk -OrgId 2 -OrgName "Foo Service" -Password not-a-real-password -Username admin
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]    
    [string]$GrafanaBaseUri,
    [Parameter(Mandatory = $true)]
    [int]$OrgId,
    [Parameter(Mandatory = $true)]
    [string]$OrgName,
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
$Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

$ExistingOrgs = Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs -Method GET -Headers $Headers
if($ExistingOrg = $ExistingOrgs | Where-Object { $_.id -eq $OrgId }) {
    Write-Output "Organisation $($ExistingOrg.name) with id $OrgId already exists."
}
else {
    Write-Output "Organisation $OrgId doesn't exist, creating ..."
    $Body = @{
        id = $OrgId
        name = $OrgName
    }
    Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs -Method POST -Body $Body -Headers $Headers
}
