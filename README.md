# Quakewatch

A tiny Flask web app that returns **“Hello, World!”** at `/`.


## Prerequisites
- **Docker Desktop** installed and running (Windows/macOS/Linux)
  - Windows: Docker Desktop with **WSL2** backend enabled is recommended
- **Network access** to pull the image from Docker Hub
- **Port 5000** available on your machine

## Quick Start (pull & run from Docker Hub)

```bash
## Pull the prebuilt image
docker pull vitalybelos112/quakewatch:0.1.0

##Run the container
docker run -d --rm --name quakewatch -p 5000:5000 vitalybelos112/quakewatch:0.1.0
