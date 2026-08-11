# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose (with BuildKit)
- Two gitignored files in the root directory:
  - **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (a raw GitHub personal access token, no `GITHUB_USERNAME` needed), AI keys (`GEMINI_API_KEY`, `CLAUDE_API_KEY`, etc.), SMTP creds.
  - **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`.
  - `GIT_AUTH_TOKEN` is passed to the backend/frontend builds as a build `ARG`, consumed inside the Dockerfiles as a git `http.extraheader` (never a URL) so it never appears in build logs or git's own output — see Security Notes in [`CLAUDE.md`](CLAUDE.md) for why this isn't a BuildKit build secret. It also needs **push/write scope** on `aleaccurso/meal-planner-backend` and `aleaccurso/meal-planner` (not just read), since `../deploy/tag-release.sh` uses it to create release tags — see Release tagging below.
- Compose itself only auto-loads a file literally named **`.env`** for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` and `.env.frontend` into the shell before calling `docker compose`, so no generated `.env` is needed. `deploy/deploy-latest.sh` does the same before building, so this holds on the NAS too — see below.
- The `deploy/` folder (a sibling of this folder, at the umbrella repo root) — it holds `tag-release.sh` and `deploy-latest.sh`. Nothing to do locally; on the NAS it must be copied over manually (see below).

## Running on Local Machine

```bash
make up
```

This sources `.env.backend`/`.env.frontend`, looks up whichever tag is already latest on each repo (see Release tagging below), builds from those tags, and starts all services. `make down` tears everything down; `make restart` does both.

## Release tagging

Both Dockerfiles clone a **tag**, not a floating branch. Tagging and deploying are two separate, explicit steps:

- **`../deploy/tag-release.sh`** — run manually whenever you want to cut a release. Mints a `v<YYYY.MM.DD>.<N>` tag per repo (independently, incrementing per day) pointing at that repo's current `main` HEAD, or reuses the existing tag if `main` hasn't moved since. Never builds or deploys anything.
- **`../deploy/deploy-latest.sh`** (what `make up` calls) — read-only. Looks up whichever tag is already latest on each repo and builds from that. If a repo has never been tagged, it fails loudly telling you to run `tag-release.sh` first, rather than silently falling back to `main`.

Because the tag name changes only when `main` has actually moved, Docker's layer cache behaves correctly on its own: an unchanged repo reuses its cached clone/dependency layers (fast rebuild), while a repo with new commits gets a fresh clone (cache correctly busted) once you've tagged it. Every tag also doubles as a permanent, human-readable record of exactly what commit was deployed and when — visible directly on GitHub.

This does mean `make up` requires network access to the GitHub API even when just restarting containers with no source changes — by design, so "build" always means "verifiably built from a specific, already-tagged commit."

## Running on Synology NAS (Container Manager)

Deployment on the NAS goes through the same scripts as local, over SSH — there is no Container Manager GUI build path. One-time setup requires copying the `deploy/` folder onto the NAS as a sibling of this project's folder, alongside the `.env.*` files:

1. Copy `.env.backend` and `.env.frontend` onto the NAS (via File Station) with production-appropriate values, including `GIT_AUTH_TOKEN` (with push/write scope — see Prerequisites) in `.env.backend`.
2. Copy the `deploy/` folder onto the NAS as a sibling of this `meal-planner-dockers` project folder.

Then, via SSH, from within `deploy/`:

```bash
./tag-release.sh      # whenever you want to cut a release
./deploy-latest.sh    # build/restart from whatever's already latest
```

The frontend will be accessible at `http://<NAS_IP>:5173` and will automatically proxy API calls to the backend container.

Both Dockerfiles clone a release tag (not the `main` branch) — see Release tagging above — so Docker's layer cache busts exactly when `main` has actually moved, with no manual cache-busting step required.

## Stop dockers

```bash
docker compose down
```

Or use the Makefile:

```bash
make down
```
