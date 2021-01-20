<#
.SYNOPSIS
Copies a file to a Kubernetes container.

.DESCRIPTION
Copies a file to a Kubernetes container using a pod label as an identifier.

.PARAMETER Namespace
The namespace of the pod containing the container that will receive the file.

.PARAMETER PodLabel
The label of the pod containing the container that will receive the file.

.PARAMETER SourceFilePath
The absolute path of the file to be copied.

.PARAMETER TargetFilePath
The absolute file path within the container.

.PARAMETER ContainerName
(optional) The name of the container, only required if the pod contains multiple containers and you do not want to target the first container.

.EXAMPLE
./Copy-FileToContainer.ps1 -Namespace foo -PodLabel app.kubernetes.io/name=bar -SourceFilePath $(Pipeline.Workspace)/foo-repo/barfile.yml -TargetFilePath /etc/foo/barfile.yml
#>
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
Write-Verbose "Copying $SourceFilePath to $TargetFile in $TargetPodName"
$CopyCommand = "kubectl cp $SourceFilePath $TargetPodName`:$TargetFilePath --namespace $Namespace"
if ($ContainerName) {
    $CopyCommand = "$CopyCommand --container $ContainerName"
}
Write-Verbose "Invoking command: $CopyCommand"
Invoke-Expression -Command $CopyCommand