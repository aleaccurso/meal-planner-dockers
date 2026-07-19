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

To pick up new backend/frontend commits, just rebuild (`make up` locally, or Build in Container Manager for production/NAS) — the Dockerfiles use BuildKit's git-context `ADD` (requires the `# syntax=docker/dockerfile:1` directive at the top of each Dockerfile) to clone `main`, which re-checks the remote ref against GitHub on every build and only reuses the cached layer if the commit is unchanged. This works with no `--no-cache` flag needed, which matters because Container Manager has no such option. There's nothing to update in this repo itself for a backend/frontend code change.

## Architecture

- **db**: `postgres:15`, healthchecked, data persisted to `${DB_DATA_PATH}`.
- **backend**: multi-stage `golang:1.25.3` build → `alpine:3.19` runtime, non-root user, depends on `db` being healthy. Clones `aleaccurso/meal-planner-backend`.
- **frontend**: multi-stage `node:25` build → `nginx:alpine` runtime. Clones `aleaccurso/meal-planner`. `frontend/nginx.conf` is a template — `VITE_APP_BACKEND_HOST`/`VITE_APP_BACKEND_PORT` are substituted at container start via `envsubst`, and it proxies `/api/` to the backend service.

Networks: `mealplanner_backend_network` (db ↔ backend) and `mealplanner_app_network` (backend ↔ frontend) — kept separate so the frontend container has no direct route to the db.

## Environment

Env vars are split by service into two gitignored files, plus a separate gitignored secret file — never commit any of them:

- **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, AI keys, SMTP creds.
- **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER` (duplicated from backend — both services need these as build args).
- **`.github_token.secret`** — raw GitHub token and nothing else, no `GITHUB_USERNAME` needed (see Security Notes below). Must have no trailing newline — BuildKit passes the file's raw bytes as the token, so a trailing `\n` silently breaks git auth (clone fails with `terminal prompts disabled`). Create/edit with `printf '%s' 'token' > .github_token.secret`, never `echo`.

Compose only auto-loads a file literally named `.env` for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` + `.env.frontend` into the shell first, so no `.env` file is needed. On the NAS (Container Manager, no shell), `.env` must be a manually maintained merge of the two files — **forgetting to re-merge after editing either file is what caused a prior production outage** (Compose interpolated empty DB credentials, Postgres refused to start, backend never connected).

`ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) selects connection details in `scripts/db-dump.sh` and `scripts/db-restore.sh`.

## Security Notes

- `.ssh/` and `auth-config.json` exist in this working copy but are gitignored — never read, print, or reference their contents.
- GitHub auth for the `ADD <git-url>` clone steps uses BuildKit's reserved `GIT_AUTH_TOKEN` build secret (declared top-level in `docker-compose.yml`, backed by `.github_token.secret`, referenced via `build.secrets` on `backend`/`frontend`) — not a build arg. This keeps the token out of the URL and out of image history/metadata entirely. Do not log build output that would echo it, and don't add `RUN echo`-style debugging around the clone step.
- `db-restore.sh` runs `DROP SCHEMA public CASCADE` before restoring — treat it as destructive; only run it (or suggest running it) with explicit user confirmation, same bar as other destructive git/db operations.

## Making Changes Here

This repo only owns Dockerfiles, `docker-compose.yml`, the Makefile, and the db backup/restore scripts. Application logic changes belong in `meal-planner-backend/` or `meal-planner/` (see root [`CLAUDE.md`](../CLAUDE.md)) — only touch this repo for deployment/infra changes (new services, env vars, nginx routing, healthchecks, base image bumps).
