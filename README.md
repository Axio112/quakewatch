# Quakewatch — Phase 1

**What this phase delivers**
- A minimal Flask app returning “Hello, World!”
- Dockerfile + optional docker-compose.yml
- A Docker image published to Docker Hub

## Local run
- Pull the image: 
vitalybelos112/quakewatch:0.1.0
- Run the container:    
docker run --rm -p 5000:5000 vitalybelos112/quakewatch:0.1.0
- Test:   
http://localhost:5000  → Hello, World!
- Test 2: 
Invoke-RestMethod http://localhost:5000 → it should return Hello, World! as well.
- to stop run:
docker stop quakewatch


- Compose: docker compose up --build -d
-to stop run: docker compose down