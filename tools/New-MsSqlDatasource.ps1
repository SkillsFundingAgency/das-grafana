<#
.SYNOPSIS
Create or update a sql database grafana datasource

.DESCRIPTION
Create or update a sql database grafana data source.

.PARAMETER GrafanaBaseUri
The base uri of the grafana instance

.PARAMETER ServerName
The name of the sql server

.PARAMETER DatabaseName
One or more databases to configure with a service account. If this parameter is not
included the default action is to include all non system databases from the server

.PARAMETER KeyVaultName
The name of the keyvault that will be used to store credentials

.PARAMETER ServiceAccountName
The name of the service account that will be created on the sql server
The default is grafana-ro-svc.

.EXAMPLE
$DataSourceParameters = @{
    GrafanaBaseUri = "https://grafana.instance.com"
    ServerName = "sql-server-name"
    DatabaseName = "database-name"
    KeyVaultName = "key-vault-name"
}

.\New-DataSource.ps1 @DataSourceParameters

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$GrafanaBaseUri,
    [Parameter(Mandatory = $true)]
    [String]$GrafanaApiToken,
    [Parameter(Mandatory = $true)]
    [String]$ServerName,
    [Parameter(Mandatory = $false)]
    [String[]]$DatabaseName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [String]$KeyVaultName,
    [Parameter(Mandatory = $false)]
    [String]$ServiceAccountName = "grafana-ro-svc"
)

. $PSScriptRoot/helpers/New-SqlDatabaseServiceAccount.ps1
. $PSScriptRoot/helpers/Invoke-GrafanaDataSourceRestMethod.ps1

try {

    Write-Verbose -Message "Getting environment from server name $ServerName"
    $Environment = $ServerName.Split("-")[1]
    Write-Verbose -Message "Environment is set to $Environment"

    if (!$PSBoundParameters.ContainsKey("DatabaseName")) {
        Write-Verbose -Message "DatabaseName parameter not present, collecting all non system databases in server $ServerName"
        $ResourceGroupName = (Get-AzResource -Name $ServerName -ResourceType "Microsoft.Sql/servers" -ErrorAction Stop).ResourceGroupName
        $DatabaseName = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName | Where-Object { $_.DatabaseName -ne "master" } | Select-Object -ExpandProperty DatabaseName
        Write-Verbose "The query has returned $($DatabaseName.Count) database(s)"
    }

    Write-Host "Processing $($DatabaseName.Count) database(s) in server $Servername ->"
    $DatabaseName | ForEach-Object {
        Write-Host "    - $_"
        Write-Host "        -> Creating service account"
        $NewSqlDatabaseServiceAccountParameters = @{
            ServerName            = $ServerName
            DataBaseName          = $_
            SqlServiceAccountName = $ServiceAccountName
            SqlServiceAccountRole = "R"
            Environment           = $Environment
            KeyVaultName          = $KeyVaultName
        }
        New-SqlDatabaseServiceAccount @NewSqlDatabaseServiceAccountParameters -Verbose:$VerbosePreference

        Write-Host "        -> Creating data source"

        $ServiceAccountSecretName = "$Environment-$ServiceAccountName".ToLower()
        $ServiceAccountPassword = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ServiceAccountSecretName).SecretValueText
        if (!$ServiceAccountPassword) {
            Write-Error -Message "Could not find a secret with name $ServiceAccountSecretName" -ErrorAction Stop
        }

        $Payload = @"
        {
            "name": "MSSQL - $_",
            "type": "mssql",
            "access": "proxy",
            "url": "$ServerName.database.windows.net:1433",
            "user": "$ServiceAccountName",
            "database": "$_",
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
            GrafanaBaseUri  = $GrafanaBaseUri
            Payload         = $Payload
            GrafanaApiToken = $GrafanaApiToken
        }

        $null = Invoke-GrafanaDataSourceRestMethod @DataSourceRestMethodParameters -Verbose:$VerbosePreference
    }

}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}
