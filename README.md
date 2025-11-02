# meal-planner-dockers

# Run dockers

```bash
GIT_REF=$(date +%s) DOCKER_BUILDKIT=1 docker compose build && docker compose up -d
```

# Stop dockers

```bash
docker compose down
```
