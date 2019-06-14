<#
.SYNOPSIS
Grafana helm chart deployment helper

.DESCRIPTION
This helper script is for development/testing scenarios only.

.PARAMETER Wait
Adds the wait argument to helm commands
#>

Param(
    [Switch]$Wait
)

if ($Wait.IsPresent){
    $_Wait = "--wait"
}

# --- Install/Upgrade chart
$Release = "das-grafana"
$GrafanaConfig = "$PSScriptRoot/helm/grafana-values.yml"
if ((helm list --output json | ConvertFrom-Json).Releases | Where-Object {$_.Name -eq $Release}){
    helm upgrade $Release stable/grafana -f $GrafanaConfig $_Wait
}else {
    helm install stable/grafana --name $Release -f $GrafanaConfig $_Wait
}

# --- Get service loadbalancer ip
$ServiceUrl = "http://$((kubectl get svc --namespace default $Release -o json | ConvertFrom-Json).status.loadBalancer.ingress[0].ip)"
$ServiceUrl | Clip
Write-Output "Service Url: $ServiceUrl has been copied to the clipboard"

# --- Get grafana password
Write-Output "Password: $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret --namespace default $Release -o json | ConvertFrom-Json).data."admin-password")))"

# --- Utility function used to generate base64 strings
function ConvertTo-Base64String{
    Param(
        [String]$InputString
    )
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    [Convert]::ToBase64String($Bytes)
}
