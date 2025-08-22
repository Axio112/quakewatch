param(
  [string]$ConfigOut = "$HOME\.kube\config.jenkins",
  [string]$MinikubeContext = "minikube",
  [string]$JenkinsContainer = "jenkins",
  [string]$JenkinsImage = "quakewatch-ci:jenkins",
  [switch]$RestartJenkins
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

Write-Info "Generating embedded kubeconfig from current minikube context..."
$embedded = "$HOME\.kube\config.embedded"
minikube kubectl -- config view --minify --flatten --raw | Out-File -Encoding ascii $embedded

Write-Info "Detecting current API server host:port (from minikube)..."
$server = minikube kubectl -- config view --minify -o jsonpath='{.clusters[0].cluster.server}'

if ($server -notmatch 'https://127\.0\.0\.1:(\d+)') {
  throw "Unexpected API server URL '$server' (expected https://127.0.0.1:<port>). Is minikube running?"
}
$port = $Matches[1]
Write-Ok "Detected apiserver port: $port"

Write-Info "Writing Jenkins-friendly kubeconfig to: $ConfigOut"
Copy-Item $embedded $ConfigOut -Force

# Point at host.docker.internal (Windows Docker Desktop) and relax TLS verification for local dev
kubectl --kubeconfig $ConfigOut config set-cluster $MinikubeContext `
  --server "https://host.docker.internal:$port" `
  --insecure-skip-tls-verify=true | Out-Null

Write-Ok "Updated server in kubeconfig => https://host.docker.internal:$port"
Write-Ok "Kubeconfig ready: $ConfigOut"

if ($RestartJenkins) {
  Write-Info "Restarting Jenkins container '$JenkinsContainer' with kubeconfig mount..."

  try { docker rm -f $JenkinsContainer 2>$null | Out-Null } catch {}

  $resolved = (Resolve-Path $ConfigOut).Path

  $args = @(
    "run","-d","--name",$JenkinsContainer,"-u","root",
    "-p","8080:8080","-p","50000:50000",
    "-v","jenkins_home:/var/jenkins_home",
    "-v","/var/run/docker.sock:/var/run/docker.sock",
    "-v","$resolved:/root/.kube/config:ro",
    "--restart","unless-stopped",
    $JenkinsImage
  )

  docker @args | Out-Null
  Write-Ok "Container '$JenkinsContainer' started using image '$JenkinsImage'"
  Start-Sleep -Seconds 10

  Write-Info "Sanity checks inside container:"
  docker exec $JenkinsContainer kubectl config current-context
  docker exec $JenkinsContainer kubectl get nodes
  Write-Ok "Jenkins sees the cluster via host.docker.internal:$port"
}

Write-Ok "Done."
