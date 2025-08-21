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
