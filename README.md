# Quakewatch — Phase 1–3 Quick README

Minimal, Windows-friendly notes for Docker → Kubernetes → Jenkins (Minikube + Docker driver).

## Prereqs
- Docker Desktop (with Kubernetes tools), Git
- Minikube (Docker driver), `kubectl`, `helm`
- Docker Hub account (credentials ID in Jenkins: `dockerhub`)

---

## Phase 1 — Docker (local)
```powershell
# From repo root
docker build -t vitalybelos112/quakewatch:dev .
docker run --rm -p 5000:5000 vitalybelos112/quakewatch:dev
# Test
curl http://localhost:5000   # -> Hello, World!
```

---

## Phase 2 — Kubernetes (Minikube)
Apply raw YAML (if needed during testing):
```powershell
kubectl apply -f k8s/
```

Access service:
```powershell
# either
minikube service quakewatch --url
# or
kubectl port-forward svc/quakewatch 5000:80
curl http://localhost:5000
```

Metrics + HPA:
```powershell
# Ensure metrics-server is enabled
minikube addons enable metrics-server

kubectl top pods -l app=quakewatch
kubectl get hpa quakewatch-hpa
```

CronJob ping (manual run & logs):
```powershell
$ts  = Get-Date -Format "yyyyMMdd-HHmmss"
$job = "quakewatch-ping-manual-$ts"
kubectl create job --from=cronjob/quakewatch-ping $job | Out-Null
kubectl wait --for=condition=complete job/$job --timeout=180s | Out-Null
$pod = kubectl get pods -l job-name=$job -o jsonpath='{.items[0].metadata.name}'
kubectl logs $pod
```

---

## Phase 3 — CI/CD with Jenkins + Helm
### Jenkins image (includes kubectl & helm)
```powershell
cd ci/jenkins
docker build -t quakewatch-ci:jenkins .
```

### Allow Jenkins-in-Docker to reach Minikube (Windows)
```powershell
# 1) Create kubeconfig that points to host.docker.internal:<apiserver-port>
$Embedded   = "$HOME\.kube\config.embedded"
minikube kubectl -- config view --minify --flatten --raw | Out-File -Encoding ascii $Embedded
$Server = minikube kubectl -- config view --minify -o jsonpath='{.clusters[0].cluster.server}'
$Port   = ([uri]$Server).Port
$JenkinsCfg = "$HOME\.kube\config.jenkins"
Copy-Item $Embedded $JenkinsCfg -Force
kubectl --kubeconfig $JenkinsCfg config set-cluster minikube `
  --server ("https://host.docker.internal:{0}" -f $Port) `
  --insecure-skip-tls-verify=true | Out-Null

# 2) Run Jenkins
docker rm -f jenkins 2>$null
docker run -d --name jenkins -u root `
  -p 8080:8080 -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "$HOME\.kube\config.jenkins:/root/.kube/config:ro" `
  --restart unless-stopped quakewatch-ci:jenkins
```

Open **http://localhost:8080** → complete setup (install suggested plugins).  
Add **Docker Hub** creds in Jenkins: ID `dockerhub` (username/password).

### Pipeline (Jenkinsfile)
- **Build:** Docker image tagged `0.1.${BUILD_NUMBER}`
- **Test:** `helm lint` + `helm template | kubectl apply --dry-run=server`
- **Publish:** Push image to Docker Hub
- **Deploy:** `helm upgrade --install quakewatch` with `--set image.*` and `--wait --atomic`
- **Smoke:** In-cluster curl to `http://quakewatch-helm/` expecting “Hello, World!”

> Chart uses `fullnameOverride=quakewatch-helm` so K8s objects stay stable.

---

## Quick Checks
```powershell
# Deployed image
kubectl get deploy quakewatch-helm -o jsonpath='{.spec.template.spec.containers[0].image}'
# Pods
kubectl get pods -l app.kubernetes.io/instance=quakewatch -o wide
# Service (port-forward)
kubectl port-forward svc/quakewatch-helm 5000:80
curl http://localhost:5000
# HPA/Metrics
kubectl top pods -l app.kubernetes.io/instance=quakewatch
kubectl get hpa quakewatch-helm
```

## Repo Layout (key)
```
charts/quakewatch/      # Helm chart (Deployment/Service/Config/HPA)
ci/jenkins/Dockerfile   # Jenkins with kubectl+helm
Jenkinsfile             # CI/CD pipeline
k8s/                    # (Optional) raw manifests used in Phase 2 experiments
app/                    # Flask Hello World
```
