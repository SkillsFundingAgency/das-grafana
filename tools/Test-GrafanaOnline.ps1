<#
.SYNOPSIS
Tests whether Grafana is online.

.DESCRIPTION
Tests whether Grafana is online using it's health check endpoint and writes the result out to an Azure DevOps variable called IsGrafanaOnline.

.PARAMETER GrafanaBaseUri
The URI of the Grafana ingress.

.PARAMETER ContinueOnTimeout
By default the script will throw an error if Grafana is not online within the timeout period.  Override this behaviour with the ContinueOnTimeout switch.

.PARAMETER Timeout
(optional) The timeout period in seconds for the script, defaults to 300 seconds.

.EXAMPLE
./Test-GrafanaOnline.ps1 -GrafanaBaseUri https://foo.grafana.gov.uk
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]    
    [string]$GrafanaBaseUri,
    [Parameter(Mandatory = $false)]    
    [switch]$ContinueOnTimeout,
    [Parameter(Mandatory = $false)]    
    [int]$Timeout = 300
)

for($t = 1; $t -le $Timeout; $t++) {
    Remove-Variable -Name Health -ErrorAction SilentlyContinue
    try {
        $Health = Invoke-RestMethod -Uri $GrafanaBaseUri/api/health
    }
    catch {
        Write-Warning "/api/health REST request failed, received response '$($_.Exception.Response.StatusCode)'"
    }
    
    if ($Health -and $Health.database -eq "ok") {
        Write-Verbose "Grafana database health ok."
        Write-Output "##vso[task.setvariable variable=IsGrafanaOnline]true" 
        break
    }
    if ($t -eq $Timeout) {
        if ($ContinueOnTimeout) {
            Write-Warning "Timed out waiting for Grafana to start"
            Write-Output "##vso[task.setvariable variable=IsGrafanaOnline]false" 
        }
        else {
            throw "Timed out waiting for Grafana to start"
        }
    }
    Start-Sleep -Seconds 1
}