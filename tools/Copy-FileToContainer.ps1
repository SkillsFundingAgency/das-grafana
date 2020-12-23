[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]    
    $Namespace,
    [Parameter(Mandatory = $true)]    
    $PodLabel,
    [Parameter(Mandatory = $true)]    
    $SourceFilePath,
    [Parameter(Mandatory = $true)]    
    $TargetFilePath,
    [Parameter(Mandatory = $false)]
    $ContainerName = ""

)

$Pods = Invoke-Expression -Command "kubectl get pods --selector $PodLabel --namespace $Namespace --output json" | ConvertFrom-Json
$TargetPodName = $Pods.items[0].metadata.name
Write-Verbose "Copying $SourceFile to $TargetFile in $TargetPodName"
$CopyCommand = "kubectl cp $SourceFile $TargetPodName`:$TargetFilePath --namespace $Namespace"
if ($ContainerName) {
    $CopyCommand = "$CopyCommand --container $ContainerName"
}
Write-Verbose "Invoking command: $CopyCommand"
Invoke-Expression -Command $CopyCommand