# Meal Planner Dockers — Claude Context

## Project

Docker Compose deployment for the Meal Planner app: `db` (PostgreSQL), `backend` (Go API), `frontend` (React SPA served by Nginx). This repo does not contain application source — the backend and frontend Dockerfiles `git clone` the `meal-planner-backend` and `meal-planner` repos directly from GitHub (`main` branch) during the image build.

Used both for local Docker runs and for deploying to a Synology NAS via Container Manager.

## Key Commands

```bash
make up          # docker compose build --no-cache && docker compose up -d
make down        # docker compose down --volumes --rmi local
make restart     # down && up
make db-dump     # ./scripts/db-dump.sh — pg_dump to $DB_DUMPS_FOLDER
make db-restore  # ./scripts/db-restore.sh — DESTRUCTIVE: drops+recreates public schema, prompts y/N
```

To pick up new backend/frontend commits, just rebuild (`make up` locally, or Build in Container Manager for production/NAS) — the Dockerfiles use BuildKit's git-context `ADD` (requires the `# syntax=docker/dockerfile:1` directive at the top of each Dockerfile) to clone `main`, which re-checks the remote ref against GitHub on every build and only reuses the cached layer if the commit is unchanged. This works with no `--no-cache` flag needed, which matters because Container Manager has no such option. There's nothing to update in this repo itself for a backend/frontend code change.

## Architecture

- **db**: `postgres:15`, healthchecked, data persisted to `${DB_DATA_PATH}`.
- **backend**: multi-stage `golang:1.25.3` build → `alpine:3.19` runtime, non-root user, depends on `db` being healthy. Clones `aleaccurso/meal-planner-backend`.
- **frontend**: multi-stage `node:25` build → `nginx:alpine` runtime. Clones `aleaccurso/meal-planner`. `frontend/nginx.conf` is a template — `VITE_APP_BACKEND_HOST`/`VITE_APP_BACKEND_PORT` are substituted at container start via `envsubst`, and it proxies `/api/` to the backend service.

Networks: `mealplanner_backend_network` (db ↔ backend) and `mealplanner_app_network` (backend ↔ frontend) — kept separate so the frontend container has no direct route to the db.

## Environment

Everything is driven by a root `.env` (gitignored, never commit it). Required vars span GitHub auth (`GITHUB_TOKEN`, `GITHUB_USERNAME` — used as Docker build args to clone the private repos), DB config (`DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`), backend config (`BACKEND_PORT`, `ENVIRONMENT`, `JWT_SECRET`, `PROJECT_ID`, `DRIVER_NAME`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`), and frontend/Firebase config (`API_BASE_URL`, `FIREBASE_*`).

`ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) selects connection details in `scripts/db-dump.sh` and `scripts/db-restore.sh`.

## Security Notes

- `.ssh/` and `auth-config.json` exist in this working copy but are gitignored — never read, print, or reference their contents.
- `GITHUB_TOKEN`/`GITHUB_USERNAME` are passed as Docker build args (`network: host`) to clone private repos over HTTPS during image build — do not log build output that would echo these, and don't add `RUN echo`-style debugging around the clone step.
- `db-restore.sh` runs `DROP SCHEMA public CASCADE` before restoring — treat it as destructive; only run it (or suggest running it) with explicit user confirmation, same bar as other destructive git/db operations.

## Making Changes Here

This repo only owns Dockerfiles, `docker-compose.yml`, the Makefile, and the db backup/restore scripts. Application logic changes belong in `meal-planner-backend/` or `meal-planner/` (see root [`CLAUDE.md`](../CLAUDE.md)) — only touch this repo for deployment/infra changes (new services, env vars, nginx routing, healthchecks, base image bumps).
