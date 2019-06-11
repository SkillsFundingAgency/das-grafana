Param(
    [Switch]$Wait
)

if ($Wait.IsPresent){
    $_Wait = "--wait"
}

# --- Install/Upgrade chart
$Release = "das-grafana"
$GrafanaConfig = "$PSScriptRoot\grafana-config.yml"
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
Write-Output "Password $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret --namespace default $Release -o json | ConvertFrom-Json).data."admin-password")))"

# --- Kill it
#.\helm.exe delete --purge $Release