function Invoke-GrafanaDataSourceRestMethod {
<#
.SYNOPSIS
Create or Update a grafana data source

.DESCRIPTION
Create or Update a grafana data source

.PARAMETER GrafanaBaseUri
The base uri of the grafana instance

.PARAMETER GrafanaApiToken
An API token that is valid for a grafana organization

The default value is ENV:GrafanaApiToken

.PARAMETER Payload
The datasource payload

.EXAMPLE
        $Payload = @"
        {
            "name": "$DataSourceName",
            "type": "mssql",
            "access": "proxy",
            "url": "$ServerName.database.windows.net:1433",
            "user": "$SqlServiceAccountName",
            "database": "$DatabaseName",
            "jsonData": {
                "maxOpenConns": 0,
                "maxIdleConns": 2,
                "connMaxLifetime": 14400
            },
            "secureJsonData": {
                "password": "$ServiceAccountPassword"
            }
        }
"@

        $DataSourceRestMethodParameters = @{
            GrafanaBaseUri = $GrafanaBaseUri
            Payload = $Payload
        }

        $null = Invoke-GrafanaDataSourceRestMethod @DataSourceRestMethodParameters -Verbose:$VerbosePreference
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$GrafanaBaseUri,
        [Parameter(Mandatory = $false)]
        [String]$GrafanaApiToken = $ENV:GrafanaApiToken,
        [Parameter(Mandatory = $true)]
        [String]$Payload
    )

    try {

        if (!$GrafanaApiToken) {
            Write-Error -Message "Could not find a valid api token" -ErrorAction Stop
        }

        $Headers = @{
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $GrafanaApiToken"
        }

        $DataSourceName = ($Payload | ConvertFrom-Json).Name

        if (!$GrafanaBaseUri.EndsWith("/")) {
            $GrafanaBaseUri = $GrafanaBaseUri.TrimEnd("/")
        }

        try {
            Write-Verbose -Message "Checking for data source $DataSourceName"
            $DataSource = Invoke-RestMethod -Method GET -Headers $Headers -Uri $GrafanaBaseUri/api/datasources/name/$DataSourceName -Verbose:$VerbosePreference
        }
        catch {
            Write-Verbose -Message "Data source $DataSourceName does not exist"
        }

        if ($DataSource) {
            Write-Verbose "Updating existing datasource $DataSourceName"
            $DataSource = (Invoke-RestMethod -Method PUT -Headers $Headers -Uri $GrafanaBaseUri/api/datasources/$($DataSource.Id) -Body $Payload -Verbose:$VerbosePreference).DataSource
        }
        else {
            Write-Verbose -Message "Creating datasource $DataSourceName"
            $DataSource = (Invoke-RestMethod -Method POST -Headers $Headers -Uri $GrafanaBaseUri/api/datasources/ -Body $Payload -Verbose:$VerbosePreference).Datasource
        }

        Write-Output $DataSource
    }
    catch {
        Write-Error "Failed to create a datasource: $_" -ErrorAction Stop
    }
}
