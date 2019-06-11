# --- Deploy tiller service account
kubectl create -f tiller-sa.yaml

# --- initi helm and tiller if it has already been installed
helm.exe init --service-account tiller --history-max 200

# --- OR if tiller is already installed on the cluster, just run
$null = helm init --client-only