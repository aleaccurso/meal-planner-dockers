# Meal Planner Dockers — Claude Context

## Project

Docker Compose deployment for the Meal Planner app: `db` (PostgreSQL), `backend` (Go API), `frontend` (React SPA served by Nginx). This repo does not contain application source — the backend and frontend Dockerfiles `git clone` (by fetching a specific ref/SHA) the repos named by `BACKEND_REPO`/`FRONTEND_REPO` (`.env.backend`, gitignored — repo names are never hardcoded in any committed file) directly from GitHub during the image build, at a `GIT_REF` build arg pinned to that repo's actual current `main` HEAD commit (see Key Commands) rather than a floating branch. Neither `GIT_REF` nor `GIT_REPO` is a `docker-compose.yml` variable with a literal value — `GIT_REPO` is interpolated from `BACKEND_REPO`/`FRONTEND_REPO`, and `GIT_REF` is passed per service directly on the `docker compose build --build-arg GIT_REF=... <service>` command line by `deploy/deploy.sh`.

Used both for local Docker runs and for deploying to a Synology NAS via Container Manager.

## Key Commands

```bash
make up          # check-env, deploy/deploy.sh — resolves each repo's main HEAD commit, source .env.backend + .env.frontend, docker compose build (per service, GIT_REF via --build-arg) && up -d --wait, then tags each deployed commit (skips minting if already tagged)
make down        # check-env, source .env.backend + .env.frontend, docker compose down --rmi local
make restart     # down && up
make db-dump     # ./scripts/db-dump.sh — pg_dump to $DB_DUMPS_FOLDER
make db-restore  # ./scripts/db-restore.sh — DESTRUCTIVE: drops+recreates public schema, prompts y/N
```

Building and tagging are a single step, in that order: build first, tag only after success. Both Dockerfiles clone a `GIT_REF` build arg — always the literal current `main` HEAD commit SHA of that repo, not a branch or pre-existing tag. `GIT_REF` is intentionally absent from `docker-compose.yml` — it's passed directly on the command line (`docker compose build --build-arg GIT_REF=<sha> <service>`) by `deploy.sh`, one invocation per service, so each of `backend`/`frontend` gets its own repo's commit. This means a bare `docker compose build` that bypasses `deploy.sh` entirely falls back to the Dockerfiles' own `ARG GIT_REF=main` default and silently builds `main` — an accepted risk, since `deploy.sh` is the only sanctioned build path. `deploy/deploy.sh` — what `make up` calls, and what you run manually via `./deploy/deploy.sh` on the NAS — resolves each repo's current `main` HEAD SHA via the GitHub API, builds and starts every service from those exact commits, waits (`docker compose up -d --wait`) for every service's healthcheck to pass, and only then mints a `v<YYYY.MM.DD>.<N>` tag per repo pointing at the commit it just deployed — reusing the existing tag instead if that commit is already tagged (e.g. re-running with nothing new to ship). If the build or the health wait fails, the script exits before touching any tags. Since the commit passed as `GIT_REF` only changes when `main` has actually moved, Docker's cache busts exactly when it should — a repo with no new commits correctly reuses its cached layers instead of rebuilding from scratch. See `deploy/deploy.sh`, `deploy/lib.sh`, and `../plans/deploy-latest-tag-without-deploy-tags-env.md` (umbrella repo, describes the predecessor two-script design that lived outside this repo) for the full history, including the cross-machine GitHub-ref locking used when minting a tag. There's nothing else to update in this repo itself for a backend/frontend code change.

## Architecture

- **db**: `postgres:15`, healthchecked, data persisted to `${DB_DATA_PATH}`.
- **backend**: multi-stage `golang:1.25.3` build → `alpine:3.19` runtime, non-root user, depends on `db` being healthy, healthchecked (`nc -z localhost 8010`). Clones `BACKEND_REPO`.
- **frontend**: multi-stage `node:25` build → `nginx:alpine` runtime, healthchecked (`wget --spider` against `/`). Clones `FRONTEND_REPO`. `frontend/nginx.conf` is a template — `VITE_APP_BACKEND_HOST`/`VITE_APP_BACKEND_PORT` are substituted at container start via `envsubst`, and it proxies `/api/` to the backend service.

Networks: `mealplanner_backend_network` (db ↔ backend) and `mealplanner_app_network` (backend ↔ frontend) — kept separate so the frontend container has no direct route to the db.

## Environment

Env vars are split by service into two gitignored files — never commit either of them:

- **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `BACKEND_REPO` (`owner/repo` — the only place this name exists; also passed to `backend/Dockerfile` as the `GIT_REPO` build arg), `GIT_AUTH_TOKEN` (raw GitHub token, no `GITHUB_USERNAME` needed, needs push/write scope on both source repos for `deploy/deploy.sh` — see Security Notes below), AI keys, SMTP creds.
- **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER` (duplicated from backend — both services need these as build args), `FRONTEND_REPO` (`owner/repo` — the only place this name exists; also passed to `frontend/Dockerfile` as the `GIT_REPO` build arg).

Compose only auto-loads a file literally named `.env` for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` + `.env.frontend` into the shell first, so no `.env` file is needed. `deploy/deploy.sh` does the same before building — both files, upfront, since it needs `BACKEND_REPO`/`FRONTEND_REPO` resolved before any build starts — so this holds on the NAS too. There is no Container Manager GUI build path and no merged `.env` file to maintain (a prior production outage was caused by exactly that merge step being forgotten; the fix was to remove the GUI path entirely rather than remember to keep re-merging).

`ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) selects connection details in `scripts/db-dump.sh` and `scripts/db-restore.sh`.

**Never edit any `.env*` file** (`.env`, `.env.backend`, `.env.frontend`, `.env.production.*`, etc.) — they hold live credentials and production config. If a value needs to change, tell the user what to change and let them edit it themselves.

## Security Notes

- `.ssh/` and `auth-config.json` exist in this working copy but are gitignored — never read, print, or reference their contents.
- GitHub auth for the git clone steps used to go through BuildKit's reserved `GIT_AUTH_TOKEN` build secret (Compose's `build.secrets`), but Synology Container Manager's compose build rejects `build.secrets` as an invalid property and doesn't honor `DOCKER_BUILDKIT=1` to fix it — its build doesn't go through BuildKit at all. So `GIT_AUTH_TOKEN` is now a plain build `ARG`, declared only in the discarded builder stage of `backend/Dockerfile`/`frontend/Dockerfile`, and passed to `git clone` via `-c http.extraheader=...` (never a URL) so it never appears in build logs or in git's own output. It does still end up in that builder stage's `docker history` (not the final runtime image) — the standard tradeoff when BuildKit secrets aren't available. Do not log build output that would echo it, and don't add `RUN echo`-style debugging around the clone step or reintroduce a URL-embedded credential.
- The same `GIT_AUTH_TOKEN` is also used by `deploy/deploy.sh` to create tags and refs via the GitHub REST API (`git/refs`, `git/tags`) on both source repos after a successful deploy, so it needs push/write scope there, not just read — it's passed as a `Bearer` header on those API calls, same never-in-a-URL principle as the clone step. The same token is also used for the read-only GET requests (main HEAD / tag lookup) earlier in the script — no separate read-only token, by design (see `../plans/deploy-latest-tag-without-deploy-tags-env.md` for the predecessor design this evolved from). `deploy/` lives inside this repo but contains no secrets itself — `GIT_AUTH_TOKEN`, `BACKEND_REPO`, and `FRONTEND_REPO` are only ever read from `.env.backend` at runtime, never hardcoded, so committing these scripts (or the Dockerfiles, which take the repo name as the `GIT_REPO` build arg) doesn't expose the token or the actual repo names.
- `db-restore.sh` runs `DROP SCHEMA public CASCADE` before restoring — treat it as destructive; only run it (or suggest running it) with explicit user confirmation, same bar as other destructive git/db operations.

## Making Changes Here

This repo owns Dockerfiles, `docker-compose.yml`, the Makefile, the db backup/restore scripts, and `deploy/` (`deploy.sh` + `lib.sh`, the build+tag pipeline). Application logic changes belong in `meal-planner-backend/` or `meal-planner/` (see root [`CLAUDE.md`](../CLAUDE.md)) — only touch this repo for deployment/infra changes (new services, env vars, nginx routing, healthchecks, base image bumps, or the deploy pipeline itself).
