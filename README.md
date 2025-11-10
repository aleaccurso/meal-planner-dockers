# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose
- A `.env` file in the root directory with the following variables:
  - `GITHUB_TOKEN`: GitHub personal access token for cloning repositories
  - `GITHUB_USERNAME`: GitHub username
  - `VITE_API_URL`: Frontend API base URL (defaults to `/api` if not set)
  - Database configuration variables (see backend `.env` requirements)
  - Backend configuration variables

## Environment Variables

The frontend uses `VITE_API_URL` to configure the API endpoint. This should be set to `/api` for production deployments where nginx proxies API requests to the backend container.

The nginx configuration proxies all `/api/` requests to the backend service at `http://backend:8010/`.

## Running on Local Machine

```bash
DOCKER_BUILDKIT=1 docker compose build && docker compose up -d
```

Or use the Makefile:

```bash
make up
```

## Running on Synology NAS

1. Clone this repository to your Synology NAS
2. Create a `.env` file with all required environment variables
3. In Container Manager:
   - Create a new project
   - Select the folder where you cloned the repository
   - Use the `docker-compose.yml` file
   - Ensure `VITE_API_URL=/api` is set (or add it to your `.env` file)
4. Build and start the containers

The frontend will be accessible at `http://<NAS_IP>:5173` and will automatically proxy API calls to the backend container.

## Stop dockers

```bash
docker compose down
```

Or use the Makefile:

```bash
make down
```
