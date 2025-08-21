# Quakewatch — Phase 1

**What this phase delivers**
- A minimal Flask app returning “Hello, World!”
- Dockerfile + optional docker-compose.yml
- A Docker image published to Docker Hub

## Local run
- Build:  docker build -t quakewatch:0.1.0 .
- Run:    docker run --rm -p 5000:5000 quakewatch:0.1.0
- Open:   http://localhost:5000  → Hello, World!
- or run: Invoke-RestMethod http://localhost:5000 → it should return Hello, World! as well.
- to stop run: docker stop quakewatch


- Compose: docker compose up --build -d
-to stop run: docker compose down