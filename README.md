# Quakewatch

A tiny Flask web app that returns **“Hello, World!”** at `/`.

---

## Phase 1 — Docker

### Prerequisites
- **Docker Desktop** installed and running (Windows/macOS/Linux)
  - Windows: Docker Desktop with **WSL2** backend enabled is recommended
- **Network access** to pull the image from Docker Hub
- **Port 5000** available on your machine

### Quick Start (pull & run from Docker Hub)

**Pull the prebuilt image**
```powershell
docker pull vitalybelos112/quakewatch:0.1.0
```

**Run the container**
```powershell
docker run -d --rm --name quakewatch -p 5000:5000 vitalybelos112/quakewatch:0.1.0
```

---

## Phase 2 — Kubernetes (local)

Run the same app on a local Kubernetes cluster (Minikube).

### Prerequisites
- **Minikube** and **kubectl** installed
- Docker Desktop running (Minikube Docker driver)
- Internet access to pull images

### Quick Start (PowerShell)
```powershell
# Start Minikube (if not already)
minikube start --driver=docker

# Deploy all Kubernetes resources from this repo
kubectl apply -f k8s/

# Get a local URL for the Service (keep this terminal open while testing)
$URL = minikube service quakewatch --url
Invoke-RestMethod $URL
```

### HPA (auto-scaling)
```powershell
# Enable metrics (needed for HPA)
minikube addons enable metrics-server

# View CPU/Memory and HPA status
kubectl top pods
kubectl get hpa
```

### CronJob (scheduled ping)
```powershell
kubectl get cronjob quakewatch-ping
kubectl get jobs -l app=quakewatch
```

### Stop / Clean up
```powershell
# Remove the app
kubectl delete -f k8s/

# Optional: stop Minikube
minikube stop
```
Quakewatch — Phase 3: CI/CD (Jenkins + Helm)
===================================================

What this phase delivers
------------------------
- Helm chart for Kubernetes in `charts/quakewatch` (Service: NodePort, liveness/readiness probes, HPA, ConfigMap w/ APP_MESSAGE, existing Secret w/ SECRET_TOKEN).
- Jenkins Pipeline (`Jenkinsfile`) that builds a Docker image, pushes to Docker Hub, and deploys/updates the release via `helm upgrade --install`.
- Image tags follow `0.1.<BUILD_NUMBER>` to tie running pods to a CI run.

Who this is for
---------------
End users who want to deploy or verify the Helm-based installation, and contributors who push to `main` to trigger automated build & deploy.

Prerequisites
-------------
- A running Kubernetes cluster (e.g., Minikube).
- Helm 3 installed on the machine running cluster operations.
- Jenkins server already configured with:
  - Docker access (to build/push images).
  - Kube access (kubeconfig set for the target cluster).
  - Docker Hub credentials (ID: `dockerhub` → Username `<dockerhub username>`, Password = Personal Access Token).
- Network access to pull from Docker Hub.

How CI/CD works
---------------
1) **Build:** Jenkins builds a new image tag `vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>` from the repo root Dockerfile.
2) **Push:** Jenkins logs in using the configured Docker Hub credential and pushes the image.
3) **Deploy:** Jenkins runs:
   ```bash
   helm upgrade --install quakewatch charts/quakewatch \
     --set image.repository=vitalybelos112/quakewatch \
     --set image.tag=0.1.<BUILD_NUMBER> \
     --wait
   ```
   This updates the Deployment managed by Helm (release name `quakewatch`).

Using it
--------
### Trigger a deploy
- **Manual:** From Jenkins UI, click **Build Now** on the pipeline.

### Verify rollout and image
```bash
kubectl rollout status deploy/quakewatch-helm
kubectl get deploy quakewatch-helm -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>
```

### Access the app (Minikube)
Terminal A (keep it open):
```bash
minikube service quakewatch-helm --url
# Copy the printed http://127.0.0.1:<PORT>; the terminal must remain open.
```
Terminal B:
```bash
curl -sS http://127.0.0.1:<PORT>
# => "Hello, World!"
```
Alternative (no tunnel):
```bash
kubectl port-forward svc/quakewatch-helm 5000:80
# then
curl -sS http://localhost:5000
```

Manual Helm usage (if needed)
-----------------------------
Install/upgrade explicitly to a tag (replace the tag as needed):
```bash
helm upgrade --install quakewatch charts/quakewatch \
  --set image.repository=vitalybelos112/quakewatch \
  --set image.tag=0.1.5 \
  --wait
```
Inspect current release:
```bash
helm get values quakewatch
helm history quakewatch
helm get manifest quakewatch | grep -i 'image:'
```

Observability & quick checks
----------------------------
```bash
# HPA status
kubectl get hpa -l app.kubernetes.io/instance=quakewatch

# Pods and ReplicaSets
kubectl get deploy,rs,pod -l app.kubernetes.io/instance=quakewatch -o wide

# Service endpoints
kubectl get svc quakewatch-helm -o wide
kubectl get endpoints quakewatch-helm -o wide
```

Refresh Jenkins kubeconfig when Minikube API port changes
---------------------------------------------------------
On Windows with Docker Desktop, the Minikube API server runs on `127.0.0.1:<random-port>` on the host. Inside the Jenkins container, `127.0.0.1` is **the container**, so we point Jenkins to `https://host.docker.internal:<port>`.

Use the helper script to regenerate a Jenkins-friendly kubeconfig and (optionally) restart the Jenkins container with the correct mount:

```powershell
# regenerate kubeconfig only
.\refresh-kubeconfig-for-jenkins.ps1

# regenerate and restart Jenkins container (name 'jenkins', image 'quakewatch-ci:jenkins')
.\refresh-kubeconfig-for-jenkins.ps1 -RestartJenkins
```

Repository structure (Phase 3 additions)
----------------------------------------
- `charts/quakewatch/` — Helm chart (Service, Deployment, HPA, ConfigMap; uses existing Secret name `quakewatch-secret`).
- `Jenkinsfile` — Pipeline that builds, pushes, and deploys with Helm.

Versioning
----------
- Images: `vitalybelos112/quakewatch:0.1.<BUILD_NUMBER>` (built by Jenkins).
- Chart: `charts/quakewatch/Chart.yaml` defines chart version; application version shown via `appVersion`.

Cleanup
-------
Remove the Helm release and its resources:
```bash
helm uninstall quakewatch
```
