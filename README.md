# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose (with BuildKit)
- Two gitignored files in the root directory:
  - **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (a raw GitHub personal access token, no `GITHUB_USERNAME` needed), `BACKEND_REPO` (`owner/repo`, e.g. `owner/meal-planner-backend`), AI keys (`GEMINI_API_KEY`, `CLAUDE_API_KEY`, etc.), SMTP creds.
  - **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `FRONTEND_REPO` (`owner/repo`, e.g. `owner/meal-planner`).
  - `GIT_AUTH_TOKEN` is passed to the backend/frontend builds as a build `ARG`, consumed inside the Dockerfiles as a git `http.extraheader` (never a URL) so it never appears in build logs or git's own output — see Security Notes in [`CLAUDE.md`](CLAUDE.md) for why this isn't a BuildKit build secret. It also needs **push/write scope** on the repos named by `BACKEND_REPO`/`FRONTEND_REPO` (not just read), since `deploy/deploy.sh` uses it to create release tags — see Release tagging below.
  - `BACKEND_REPO`/`FRONTEND_REPO` are also passed to their respective builds as the `GIT_REPO` build `ARG` (the source to `git clone`) — kept out of every committed file (Dockerfiles, scripts, docs) and read only from these gitignored env files, so the actual repo names never appear anywhere version-controlled.
- Compose itself only auto-loads a file literally named **`.env`** for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` and `.env.frontend` into the shell before calling `docker compose`, so no generated `.env` is needed. `deploy/deploy.sh` does the same before building (both files, upfront — it needs `BACKEND_REPO` and `FRONTEND_REPO` resolved before any build starts), so this holds on the NAS too — see below.
- The `deploy/` folder (`deploy.sh` + `lib.sh`) lives inside this repo, so it's already present wherever `meal-planner-dockers` itself is checked out or pulled — no separate copy step. It contains no secrets: `GIT_AUTH_TOKEN` is always read from `.env.backend` at runtime, never embedded in the scripts.

## Running on Local Machine

```bash
make up
```

This sources `.env.backend`/`.env.frontend`, builds every service from each repo's actual current `main` HEAD commit, starts all services, waits for them to report healthy, and only then tags each deployed commit (see Release tagging below). `make down` tears everything down; `make restart` does both.

## Release tagging

Both Dockerfiles clone a **specific commit**, not a floating branch — `deploy/deploy.sh` (what `make up` calls) does it all in one step:

1. Resolves each repo's (`BACKEND_REPO`, `FRONTEND_REPO`) actual current `main` HEAD commit SHA via the GitHub API.
2. Builds every service from that exact commit — passing the SHA straight to `docker compose build --build-arg GIT_REF=... <service>` on the command line (`GIT_REF` is never an environment variable or something `docker-compose.yml` interpolates, so there's nothing for it to be silently unset) — then runs `docker compose up -d --wait`, which blocks until every service reports healthy and fails loudly if anything doesn't.
3. Only if that succeeds: for each repo, reuses the existing `v<YYYY.MM.DD>.<N>` tag if that exact commit is already tagged (e.g. re-running with no new commits), or mints the next one for today pointing at that commit.

A bare `docker compose build` that bypasses `deploy.sh` entirely will silently fall back to the Dockerfiles' own `ARG GIT_REF=main` default — `deploy.sh` is the only supported way to build.

Because the commit passed to `GIT_REF` only changes when `main` has actually moved, Docker's layer cache behaves correctly on its own: an unchanged repo reuses its cached clone/dependency layers (fast rebuild), while a repo with new commits gets a fresh clone (cache correctly busted). Every tag doubles as a permanent, human-readable record of exactly what commit was deployed and when — visible directly on GitHub — and only ever gets created once that commit is confirmed running and healthy.

This does mean `make up` requires network access to the GitHub API even when just restarting containers with no source changes — by design, so "deployed" always means "verifiably built and healthy from a specific commit, tagged after the fact."

## Running on Synology NAS (Container Manager)

Deployment on the NAS goes through the same script as local, over SSH — there is no Container Manager GUI build path. `deploy/` is part of this repo, so it's already wherever `meal-planner-dockers` is checked out on the NAS. One-time setup is just the env files:

1. Copy `.env.backend` and `.env.frontend` onto the NAS (via File Station) with production-appropriate values, including `GIT_AUTH_TOKEN`, `BACKEND_REPO` (with push/write scope — see Prerequisites) in `.env.backend`, and `FRONTEND_REPO` in `.env.frontend`.

Then, via SSH, from within `meal-planner-dockers/`:

```bash
./deploy/deploy.sh    # always builds+deploys the current main HEAD of each repo, tags on success
# or: make up
```

The frontend will be accessible at `http://<NAS_IP>:5173` and will automatically proxy API calls to the backend container.

Both Dockerfiles clone a specific commit (not the `main` branch directly) — see Release tagging above — so Docker's layer cache busts exactly when `main` has actually moved, with no manual cache-busting step required.

## Stop dockers

```bash
docker compose down
```

Or use the Makefile:

```bash
make down
```
