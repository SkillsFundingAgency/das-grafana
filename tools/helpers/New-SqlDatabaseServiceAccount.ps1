function New-SqlDatabaseServiceAccount {
<#
.SYNOPSIS
Create A Sql Database Service Account Automation

.DESCRIPTION
Create A Sql Database Service Account Automation

.PARAMETER ServerName
Name of the SQL Server

.PARAMETER AzureFireWallName
Name of the temporary Sql Server FireWall rule created (Optional)

.PARAMETER SqlServiceAccountName
The name of the service account to be created.

.PARAMETER SqlServiceAccountRole
The role to add the new service account to. Value can be R, RO, RWE. The Default is RWE.

.PARAMETER Environment
The Environment of the New Service account,

.PARAMETER KeyVaultName
The name of the Keyvault for the Environment

.EXAMPLE
$NewSqlDBAccountParameters = @{
	 ServerName = $ServerName
     DataBaseName = $DataBaseName
     SqlServiceAccountName = $SqlServiceAccountName
     Environment = $Environment
     KeyVaultName = $KeyVaultName
}

.\New-SqlDbServiceAccount.ps1 @NewSqlDBAccountParameters

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$ServerName,
        [Parameter(Mandatory = $false)]
        [String]$AzureFirewallName = "AzureWebAppFirewall",
        [Parameter(Mandatory = $true)]
        [String]$DataBaseName,
        [Parameter(Mandatory = $true)]
        [String]$SqlServiceAccountName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("R", "RW", "RWE")]
        [String]$SqlServiceAccountRole = "RWE",
        [Parameter(Mandatory = $true)]
        [String]$Environment,
        [Parameter(Mandatory = $true)]
        [String]$KeyVaultName
    )

    $ErrorActionPreference = 'Stop'

    function Get-RandomPassword {
        -join ('abcdefghkmnrstuvwxyzABCDEFGHKLMNPRSTUVWXYZ23456789!%(*#'.ToCharArray() | Get-Random -Count 16)
    }

    try {
        $AgentIP = (Invoke-WebRequest ifconfig.me/ip -UseBasicParsing).Content.Trim()
        $ServiceAccountSecretName = "$Environment-$SqlServiceAccountName".ToLower()
        $ServerFQDN = "$ServerName.database.windows.net"

        # --- Retrieve SQL Server details
        Write-Verbose -Message "Searching for server resource $($ServerName)"
        $ServerResource = Get-AzResource -Name $ServerName -ResourceType "Microsoft.Sql/servers"
        if (!$ServerResource) {
            throw "Could not find SQL server with name $ServerName"
        }

        Write-Verbose -Message "Retrieving server login details"
        $SqlServerUserName = (Get-AzSqlServer -ResourceGroupName $ServerResource.ResourceGroupName -ServerName $ServerName).SqlAdministratorLogin

        Write-Verbose -Message "Retrieving secure server password"
        $SqlServerPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ServerName -AsPlainText
        if (!$SqlServerPassword) {
            throw "Could not retrieve secure password for $ServerName"
        }

        # --- Add agent IP exception to the firewall
        Write-Verbose -Message "Updating firewall rule with agent ip: $AgentIP"
        $FirewallUpdateParameters = @{
            StartIPAddress    = $AgentIp
            EndIPAddress      = $AgentIp
            FirewallRuleName  = $AzureFirewallName
            ServerName        = $ServerName
            ResourceGroupName = $ServerResource.ResourceGroupName
        }

        if (!(Get-AzSqlServerFirewallRule -ServerName $ServerName -ResourceGroupName $ServerResource.ResourceGroupName -FirewallRuleName $AzureFirewallName -ErrorAction SilentlyContinue)) {
            $null = New-AzSqlServerFirewallRule @FirewallUpdateParameters
        }
        else {
            $null = Set-AzSqlServerFirewallRule @FirewallUpdateParameters
        }

        # --- Retrieve or set service account password
        Write-Verbose -Message "Creating service account: $SqlServiceAccountName"
        $ServiceAccountPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ServiceAccountSecretName -AsPlainText
        if (!$ServiceAccountPassword) {
            $ServiceAccountPassword = Get-RandomPassword
            $SecureAccountPassword = $ServiceAccountPassword | ConvertTo-SecureString -AsPlainText -Force
            $null = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ServiceAccountSecretName -SecretValue $SecureAccountPassword -Verbose:$VerbosePreference
        }

        switch ($SqlServiceAccountRole) {
            'R' {
                $Role = @"
                ALTER ROLE db_datareader
                ADD MEMBER "$($SqlServiceAccountName)"
                ALTER ROLE db_datawriter
                DROP MEMBER "$($SqlServiceAccountName)"
                REVOKE EXECUTE FROM "$($SqlServiceAccountName)"
"@
                break
            }

            'RW' {
                $Role = @"
                ALTER ROLE db_datareader
                ADD MEMBER "$($SqlServiceAccountName)"
                ALTER ROLE db_datawriter
                ADD MEMBER "$($SqlServiceAccountName)"
                REVOKE EXECUTE FROM "$($SqlServiceAccountName)"
"@
                break
            }

            'RWE' {
                $Role = @"
                ALTER ROLE db_datareader
                ADD MEMBER "$($SqlServiceAccountName)"
                ALTER ROLE db_datawriter
                ADD MEMBER "$($SqlServiceAccountName)"
                GRANT EXECUTE TO "$($SqlServiceAccountName)"
"@
                break
            }
        }

        # --- Execute query
        $Query = @"
        IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE NAME = '$($SqlServiceAccountName)') BEGIN
            CREATE USER "$($SqlServiceAccountName)" WITH PASSWORD = '$($ServiceAccountPassword)';
        END

        $($Role)
"@

        $SQLCmdParameters = @{
            ServerInstance  = $ServerFQDN
            Database        = $DataBaseName
            Username        = $SqlServerUserName
            Password        = $SqlServerPassword
            OutputSqlErrors = $true
            Query           = $Query
        }

        Invoke-Sqlcmd @SQLCmdParameters

        if ($ENV:TF_BUILD) {
            Write-Host "##vso[task.setvariable variable=SQLServerServiceAccountUsername]$SqlServiceAccountName"
            Write-Host "##vso[task.setvariable variable=SQLServerServiceAccountPassword;issecret=true]$ServiceAccountPassword"
        }
    }
    catch {
        throw "$_"
    }
    finally {
        $ServerResource = Get-AzResource -Name $ServerName -ResourceType "Microsoft.Sql/servers"
        if ((Get-AzSqlServerFirewallRule -ServerName $ServerName -ResourceGroupName $ServerResource.ResourceGroupName -FirewallRuleName $AzureFirewallName -ErrorAction SilentlyContinue)) {
            $null = Remove-AzSqlServerFirewallRule -FirewallRuleName $AzureFirewallName -ServerName $ServerName -ResourceGroupName $ServerResource.ResourceGroupName
        }
    }
}
