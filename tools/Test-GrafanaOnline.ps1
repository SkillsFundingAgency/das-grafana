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