# Quakewatch

A tiny Flask web app that returns **“Hello, World!”** at `/` — packaged for Docker, Kubernetes (Minikube), and Helm with a Jenkins CI/CD pipeline.

---

## Phase 1 — Docker (local run)

### Prerequisites

- **Docker Desktop** running (Windows/macOS/Linux)
- **Network access** to pull the image from Docker Hub
- **Port 5000** available

### Quick Start (PowerShell)

**Pull the prebuilt image**

```powershell
docker pull vitalybelos112/quakewatch:0.1.0
```

**Run the container**

```powershell
docker run -d --rm --name quakewatch -p 5000:5000 vitalybelos112/quakewatch:0.1.0
```

**Test**

```powershell
Invoke-RestMethod http://localhost:5000
# => Hello, World!
```

**Stop**

```powershell
docker stop quakewatch
```

---

## Phase 2 — Kubernetes with Minikube

Run the same app on a local Kubernetes cluster.

### Prerequisites

- **Minikube** and **kubectl** installed
- Docker Desktop running (Minikube Docker driver)
- Internet access to pull images

### Deploy (PowerShell)

```powershell
# Start Minikube (if not already)
minikube start --driver=docker

# Apply the Kubernetes manifests from this repo
kubectl apply -f k8s/

# Wait for rollout
kubectl rollout status deploy/quakewatch
```

### Access the Service

```powershell
# Get a local URL (keep this terminal open while testing)
$URL = minikube service quakewatch --url
Invoke-RestMethod $URL
# => Hello, World!
```

### Autoscaling (HPA)

```powershell
# Enable metrics (required for HPA CPU targets)
minikube addons enable metrics-server

# View resource usage and HPA status
kubectl top nodes
kubectl top pods
kubectl get hpa
```

### Scheduled check (CronJob)

```powershell
# CronJob created in k8s/ will periodically curl the service
kubectl get cronjob quakewatch-ping
kubectl get jobs -l app=quakewatch
```

### Clean up

```powershell
kubectl delete -f k8s/
# Optional:
minikube stop
```

---

## Phase 3 — CI/CD (Jenkins + Helm)

This repo contains a **Helm chart** and a **Jenkinsfile** that build a Docker image, push it to Docker Hub, and deploy it to Minikube via `helm upgrade --install`.

### What’s included

- **Helm chart** in `charts/quakewatch`
  - Service (NodePort), Deployment (probes/resources), HPA, ConfigMap (`APP_MESSAGE`), existing Secret (`SECRET_TOKEN`)
- **Jenkinsfile** (pipeline)
  - Build → Push → Deploy with Helm using image tag `0.1.<BUILD_NUMBER>`

### How to use it (end‑user)

- **Manual CI run:** In Jenkins UI, run **Build Now** on the pipeline for this repo.
- **What it does:**
  1. Builds `vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>`
  2. Pushes to Docker Hub (`vitalybelos112`)
  3. Deploys with Helm:
     ```bash
     helm upgrade --install quakewatch charts/quakewatch \
       --set image.repository=vitalybelos112/quakewatch \
       --set image.tag=0.1.<BUILD_NUMBER> \
       --wait
     ```

### Verify the deploy

```powershell
# Rollout should complete
kubectl rollout status deploy/quakewatch-helm

# Running image should match 0.1.<BUILD_NUMBER>
kubectl get deploy quakewatch-helm -o jsonpath='{.spec.template.spec.containers[0].image}'; ""
# Expected: vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>
```

### Access the app (Minikube)

```powershell
# Keep this terminal open (tunnel stays active)
minikube service quakewatch-helm --url
# Copy the printed http://127.0.0.1:<PORT> and test in another terminal:
Invoke-RestMethod http://127.0.0.1:<PORT>
# => Hello, World!
```

**Alternative (no tunnel)**

```powershell
kubectl port-forward svc/quakewatch-helm 5000:80
Invoke-RestMethod http://localhost:5000
```

### Manual Helm usage (optional)

```powershell
# Install/upgrade to a specific image tag
helm upgrade --install quakewatch charts/quakewatch `
  --set image.repository=vitalybelos112/quakewatch `
  --set image.tag=0.1.5 `
  --wait

# Inspect the release
helm get values quakewatch
helm history quakewatch
helm get manifest quakewatch | Select-String 'image:'
```

### If Jenkins can’t reach the cluster (Windows, Docker driver)

When Minikube restarts, its API server port can change (e.g., `https://127.0.0.1:<random>`). Inside the Jenkins **container**, `127.0.0.1` points to the container itself. Regenerate a kubeconfig that points Jenkins to `host.docker.internal:<port>` and restart the container with that file mounted.

```powershell
# 1) Build a kubeconfig Jenkins can use
$Embedded   = "$HOME\.kube\config.embedded"
minikube kubectl -- config view --minify --flatten --raw | Out-File -Encoding ascii $Embedded

$Server     = minikube kubectl -- config view --minify -o jsonpath='{.clusters[0].cluster.server}'
$Port       = ($Server -replace 'https://127\.0\.0\.1:', '')
$JenkinsCfg = "$HOME\.kube\config.jenkins"

Copy-Item $Embedded $JenkinsCfg -Force
kubectl --kubeconfig $JenkinsCfg config set-cluster minikube `
  --server "https://host.docker.internal:$Port" `
  --insecure-skip-tls-verify=true | Out-Null

# 2) Restart Jenkins with this kubeconfig mounted (PowerShell-safe)
docker rm -f jenkins
$Resolved = (Resolve-Path $JenkinsCfg).Path
$Mount    = ('{0}:/root/.kube/config:ro' -f $Resolved)

docker run -d --name jenkins -u root `
  -p 8080:8080 -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v $Mount `
  --restart unless-stopped quakewatch-ci:jenkins

# 3) Sanity checks
docker exec jenkins kubectl config current-context
docker exec jenkins kubectl get nodes             # should list the minikube node
```

> PowerShell tip: after jsonpath commands use `; ""` to print a newline instead of `; echo`.

### Troubleshooting

- **Image didn’t update after a build**

  ```powershell
  helm get values quakewatch
  helm get manifest quakewatch | Select-String 'image:'
  kubectl get deploy quakewatch-helm -o jsonpath='{.spec.template.spec.containers[0].image}'; ""
  ```

  Re-run the Jenkins job or apply a manual `helm upgrade` with `--set image.tag=...`.

- **Minikube URL closes when terminal closes**  
  Keep the `minikube service ... --url` terminal open, or use `kubectl port-forward`.

---

## Repository Map

- `app/` — Minimal Flask app
- `Dockerfile` — Image for Phase 1 & CI builds
- `k8s/` — Raw Kubernetes manifests used in Phase 2 (Deployment/Service/HPA/CronJob/ConfigMap/Secret)
- `charts/quakewatch/` — Helm chart (used by Phase 3)
- `Jenkinsfile` — Pipeline: build → push → helm upgrade/install

## Versions

- Images: `vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>` (built by Jenkins)
- Chart: `charts/quakewatch/Chart.yaml` (versioned via `version`; app version via `appVersion`)

## Cleanup

```powershell
# Docker
docker stop quakewatch

# Kubernetes (raw manifests)
kubectl delete -f k8s/

# Helm release
helm uninstall quakewatch
```
