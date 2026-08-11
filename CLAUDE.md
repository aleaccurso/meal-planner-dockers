# Meal Planner Dockers — Claude Context

## Project

Docker Compose deployment for the Meal Planner app: `db` (PostgreSQL), `backend` (Go API), `frontend` (React SPA served by Nginx). This repo does not contain application source — the backend and frontend Dockerfiles `git clone` the `meal-planner-backend` and `meal-planner` repos directly from GitHub during the image build, at a `GIT_REF` build arg pinned to an auto-generated release tag (see Key Commands) rather than the `main` branch directly. `GIT_REF` is not a `docker-compose.yml` variable — it's passed per service directly on the `docker compose build --build-arg GIT_REF=... <service>` command line by `../deploy/deploy-latest.sh`.

Used both for local Docker runs and for deploying to a Synology NAS via Container Manager.

## Key Commands

```bash
make up          # check-env, ../deploy/deploy-latest.sh — reads each repo's latest tag, source .env.backend + .env.frontend, docker compose build (per service, GIT_REF via --build-arg) && up -d
make tag-release # check-env, ../deploy/tag-release.sh — mints (or reuses) a release tag per repo; run manually whenever cutting a release
make down        # check-env, source .env.backend + .env.frontend, docker compose down --rmi local
make restart     # down && up
make db-dump     # ./scripts/db-dump.sh — pg_dump to $DB_DUMPS_FOLDER
make db-restore  # ./scripts/db-restore.sh — DESTRUCTIVE: drops+recreates public schema, prompts y/N
```

Tagging and deploying are separate steps. Both Dockerfiles clone a `GIT_REF` build arg (a tag, not the `main` branch). `GIT_REF` is intentionally absent from `docker-compose.yml` — it's passed directly on the command line (`docker compose build --build-arg GIT_REF=<tag> <service>`) by `deploy-latest.sh`, one invocation per service, so each of `backend`/`frontend` gets its own repo's tag. This means a bare `docker compose build` that bypasses `deploy-latest.sh` entirely falls back to the Dockerfiles' own `ARG GIT_REF=main` default and silently builds `main` — an accepted risk, since `deploy-latest.sh` is the only sanctioned build path (see `../plans/deploy-latest-tag-without-deploy-tags-env.md` section 11 for why). `../deploy/tag-release.sh` — run manually, locally or via `./tag-release.sh` on the NAS, whenever you want to cut a release — mints a fresh `v<YYYY.MM.DD>.<N>` tag per repo whenever that repo's `main` has moved (or reuses the existing tag if not). `../deploy/deploy-latest.sh` — what `make up` calls, and what you run manually via `./deploy-latest.sh` on the NAS — is read-only: it looks up whichever tag is already latest per repo and builds from that, failing loudly if a repo has never been tagged rather than falling back to `main`. Since the tag value only ever changes when there's something new to ship, Docker's cache busts exactly when it should — a repo with no new commits correctly reuses its cached layers instead of rebuilding from scratch. See `../deploy/tag-release.sh`, `../deploy/deploy-latest.sh`, and `../plans/deploy-latest-tag-without-deploy-tags-env.md` (umbrella repo) for the full design, including the cross-machine GitHub-ref locking used by `tag-release.sh`. There's nothing else to update in this repo itself for a backend/frontend code change.

## Architecture

- **db**: `postgres:15`, healthchecked, data persisted to `${DB_DATA_PATH}`.
- **backend**: multi-stage `golang:1.25.3` build → `alpine:3.19` runtime, non-root user, depends on `db` being healthy. Clones `aleaccurso/meal-planner-backend`.
- **frontend**: multi-stage `node:25` build → `nginx:alpine` runtime. Clones `aleaccurso/meal-planner`. `frontend/nginx.conf` is a template — `VITE_APP_BACKEND_HOST`/`VITE_APP_BACKEND_PORT` are substituted at container start via `envsubst`, and it proxies `/api/` to the backend service.

Networks: `mealplanner_backend_network` (db ↔ backend) and `mealplanner_app_network` (backend ↔ frontend) — kept separate so the frontend container has no direct route to the db.

## Environment

Env vars are split by service into two gitignored files — never commit either of them:

- **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (raw GitHub token, no `GITHUB_USERNAME` needed, needs push/write scope on both source repos for `../deploy/tag-release.sh` — see Security Notes below), AI keys, SMTP creds.
- **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER` (duplicated from backend — both services need these as build args).

Compose only auto-loads a file literally named `.env` for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` + `.env.frontend` into the shell first, so no `.env` file is needed. `../deploy/deploy-latest.sh` does the same before building, so this holds on the NAS too — there is no Container Manager GUI build path and no merged `.env` file to maintain (a prior production outage was caused by exactly that merge step being forgotten; the fix was to remove the GUI path entirely rather than remember to keep re-merging).

`ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) selects connection details in `scripts/db-dump.sh` and `scripts/db-restore.sh`.

**Never edit any `.env*` file** (`.env`, `.env.backend`, `.env.frontend`, `.env.production.*`, etc.) — they hold live credentials and production config. If a value needs to change, tell the user what to change and let them edit it themselves.

## Security Notes

- `.ssh/` and `auth-config.json` exist in this working copy but are gitignored — never read, print, or reference their contents.
- GitHub auth for the git clone steps used to go through BuildKit's reserved `GIT_AUTH_TOKEN` build secret (Compose's `build.secrets`), but Synology Container Manager's compose build rejects `build.secrets` as an invalid property and doesn't honor `DOCKER_BUILDKIT=1` to fix it — its build doesn't go through BuildKit at all. So `GIT_AUTH_TOKEN` is now a plain build `ARG`, declared only in the discarded builder stage of `backend/Dockerfile`/`frontend/Dockerfile`, and passed to `git clone` via `-c http.extraheader=...` (never a URL) so it never appears in build logs or in git's own output. It does still end up in that builder stage's `docker history` (not the final runtime image) — the standard tradeoff when BuildKit secrets aren't available. Do not log build output that would echo it, and don't add `RUN echo`-style debugging around the clone step or reintroduce a URL-embedded credential.
- The same `GIT_AUTH_TOKEN` is also used by `../deploy/tag-release.sh` to create tags and refs via the GitHub REST API (`git/refs`, `git/tags`) on both source repos, so it needs push/write scope there, not just read — it's passed as a `Bearer` header on those API calls, same never-in-a-URL principle as the clone step. `../deploy/deploy-latest.sh` reuses the same token but only ever issues GET requests (tag lookup) — no separate read-only token, by design (see `../plans/deploy-latest-tag-without-deploy-tags-env.md`).
- `db-restore.sh` runs `DROP SCHEMA public CASCADE` before restoring — treat it as destructive; only run it (or suggest running it) with explicit user confirmation, same bar as other destructive git/db operations.

## Making Changes Here

This repo only owns Dockerfiles, `docker-compose.yml`, the Makefile, and the db backup/restore scripts. Application logic changes belong in `meal-planner-backend/` or `meal-planner/` (see root [`CLAUDE.md`](../CLAUDE.md)) — only touch this repo for deployment/infra changes (new services, env vars, nginx routing, healthchecks, base image bumps). `../deploy/tag-release.sh`, `../deploy/deploy-latest.sh`, and `../deploy/lib.sh` live outside this repo, in the umbrella repo's `deploy/` folder — they're referenced from here (Makefile, docs) but not owned or version-controlled by this repo.
