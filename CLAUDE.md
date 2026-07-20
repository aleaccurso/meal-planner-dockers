# Meal Planner Dockers — Claude Context

## Project

Docker Compose deployment for the Meal Planner app: `db` (PostgreSQL), `backend` (Go API), `frontend` (React SPA served by Nginx). This repo does not contain application source — the backend and frontend Dockerfiles `git clone` the `meal-planner-backend` and `meal-planner` repos directly from GitHub (`main` branch) during the image build.

Used both for local Docker runs and for deploying to a Synology NAS via Container Manager.

## Key Commands

```bash
make up          # check-env, source .env.backend + .env.frontend, docker compose build && up -d
make down        # check-env, source .env.backend + .env.frontend, docker compose down --rmi local
make restart     # down && up
make db-dump     # ./scripts/db-dump.sh — pg_dump to $DB_DUMPS_FOLDER
make db-restore  # ./scripts/db-restore.sh — DESTRUCTIVE: drops+recreates public schema, prompts y/N
```

To pick up new backend/frontend commits, rebuild (`make up` locally, or Build in Container Manager for production/NAS). The clone step is a plain `RUN git clone` (see Security Notes below for why), so it follows normal Docker layer caching — if a rebuild reuses a warm cache and doesn't pick up new commits, prune the cached builder-stage image for that service (Container Manager has no `--no-cache` option) before rebuilding. There's nothing to update in this repo itself for a backend/frontend code change.

## Architecture

- **db**: `postgres:15`, healthchecked, data persisted to `${DB_DATA_PATH}`.
- **backend**: multi-stage `golang:1.25.3` build → `alpine:3.19` runtime, non-root user, depends on `db` being healthy. Clones `aleaccurso/meal-planner-backend`.
- **frontend**: multi-stage `node:25` build → `nginx:alpine` runtime. Clones `aleaccurso/meal-planner`. `frontend/nginx.conf` is a template — `VITE_APP_BACKEND_HOST`/`VITE_APP_BACKEND_PORT` are substituted at container start via `envsubst`, and it proxies `/api/` to the backend service.

Networks: `mealplanner_backend_network` (db ↔ backend) and `mealplanner_app_network` (backend ↔ frontend) — kept separate so the frontend container has no direct route to the db.

## Environment

Env vars are split by service into two gitignored files — never commit either of them:

- **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (raw GitHub token, no `GITHUB_USERNAME` needed — see Security Notes below), AI keys, SMTP creds.
- **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER` (duplicated from backend — both services need these as build args).

Compose only auto-loads a file literally named `.env` for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` + `.env.frontend` into the shell first, so no `.env` file is needed. On the NAS (Container Manager, no shell), `.env` must be a manually maintained merge of the two files — **forgetting to re-merge after editing either file is what caused a prior production outage** (Compose interpolated empty DB credentials, Postgres refused to start, backend never connected).

`ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) selects connection details in `scripts/db-dump.sh` and `scripts/db-restore.sh`.

## Security Notes

- `.ssh/` and `auth-config.json` exist in this working copy but are gitignored — never read, print, or reference their contents.
- GitHub auth for the git clone steps used to go through BuildKit's reserved `GIT_AUTH_TOKEN` build secret (Compose's `build.secrets`), but Synology Container Manager's compose build rejects `build.secrets` as an invalid property and doesn't honor `DOCKER_BUILDKIT=1` to fix it — its build doesn't go through BuildKit at all. So `GIT_AUTH_TOKEN` is now a plain build `ARG`, declared only in the discarded builder stage of `backend/Dockerfile`/`frontend/Dockerfile`, and passed to `git clone` via `-c http.extraheader=...` (never a URL) so it never appears in build logs or in git's own output. It does still end up in that builder stage's `docker history` (not the final runtime image) — the standard tradeoff when BuildKit secrets aren't available. Do not log build output that would echo it, and don't add `RUN echo`-style debugging around the clone step or reintroduce a URL-embedded credential.
- `db-restore.sh` runs `DROP SCHEMA public CASCADE` before restoring — treat it as destructive; only run it (or suggest running it) with explicit user confirmation, same bar as other destructive git/db operations.

## Making Changes Here

This repo only owns Dockerfiles, `docker-compose.yml`, the Makefile, and the db backup/restore scripts. Application logic changes belong in `meal-planner-backend/` or `meal-planner/` (see root [`CLAUDE.md`](../CLAUDE.md)) — only touch this repo for deployment/infra changes (new services, env vars, nginx routing, healthchecks, base image bumps).
