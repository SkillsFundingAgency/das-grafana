[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$GrafanaBaseUri,
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

. $PSScriptRoot/New-SqlDatabaseServiceAccount.ps1
. $PSScriptRoot/Set-MSSQLDataSource.ps1


try {

    Write-Verbose -Message "Getting environment from server name $ServerName"
    $Environment = $ServerName.Split("-")[1]
    Write-Verbose -Message "Environment is set to $Environment"

    if (!$PSBoundParameters.ContainsKey("DatabaseName")) {
        Write-Verbose -Message "DatabaseName parameter not present, collecting all non system databases in server $ServerName"
        $ResourceGroupName = (Get-AzResource -Name $ServerName -ResourceType "Microsoft.Sql/servers" -ErrorAction Stop).ResourceGroupName
        $DatabaseName = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName | Where-Object {$_.DatabaseName -ne "master"} | Select-Object -ExpandProperty DatabaseName
        Write-Verbose "The query has returned $($DatabaseName.Count) database(s)"
    }

    Write-Host "Processing $($DatabaseName.Count) database(s) in server $Servername ->"
    $DatabaseName | ForEach-Object {
        Write-Host "    - $_"
        Write-Host "        -> Creating service account"
        $NewSqlDatabaseServiceAccountParameters = @{
            ServerName = $ServerName
            DataBaseName = $_
            SqlServiceAccountName = $ServiceAccountName
            SqlServiceAccountRole = "R"
            Environment = $Environment
            KeyVaultName = $KeyVaultName
        }
        New-SqlDatabaseServiceAccount @NewSqlDatabaseServiceAccountParameters -Verbose:$VerbosePreference

        Write-Host "        -> Creating data source"
        $NewGrafanaSqlDataSourceParameters = @{
            GrafanaBaseUri = $GrafanaBaseUri
            ServerName = $ServerName
            DatabaseName = $_
            Environment = $Environment
            SqlServiceAccountName = $ServiceAccountName
            KeyVaultName = $KeyVaultName
        }

        $null = Set-MSSQLSqlDataSource @NewGrafanaSqlDataSourceParameters -Verbose:$VerbosePreference
    }

} catch {
    $PSCmdlet.ThrowTerminatingError($_)
}
