# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose (with BuildKit)
- Two gitignored files in the root directory:
  - **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (a raw GitHub personal access token, no `GITHUB_USERNAME` needed), AI keys (`GEMINI_API_KEY`, `CLAUDE_API_KEY`, etc.), SMTP creds.
  - **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`.
  - `GIT_AUTH_TOKEN` is passed to the backend/frontend builds as a build `ARG`, consumed inside the Dockerfiles as a git `http.extraheader` (never a URL) so it never appears in build logs or git's own output — see Security Notes in [`CLAUDE.md`](CLAUDE.md) for why this isn't a BuildKit build secret. It also needs **push/write scope** on `aleaccurso/meal-planner-backend` and `aleaccurso/meal-planner` (not just read), since `../deploy/tag-release.sh` uses it to create release tags — see Release tagging below.
- Compose itself only auto-loads a file literally named **`.env`** for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` and `.env.frontend` into the shell before calling `docker compose`, so no generated `.env` is needed. On the NAS (no shell/Makefile — see below) you must maintain `.env` yourself as a merged copy of the other two files.
- The `deploy/` folder (a sibling of this folder, at the umbrella repo root) — it holds `tag-release.sh`, which `make up` calls automatically. Nothing to do locally; on the NAS it must be copied over manually (see below).

## Running on Local Machine

```bash
make up
```

This sources `.env.backend`/`.env.frontend`, tags the current `main` HEAD of both repos (see Release tagging below), builds from those tags, and starts all services. `make down` tears everything down; `make restart` does both.

## Release tagging

Both Dockerfiles clone a **tag**, not a floating branch — `../deploy/tag-release.sh` mints a `v<YYYY.MM.DD>.<N>` tag per repo (independently, incrementing per day) pointing at that repo's current `main` HEAD, and writes the resulting tag names to a generated `.deploy-tags.env`. `make up` calls this automatically before building, so it's always working from a real, current commit — never a stale cached clone.

Because the tag name changes only when `main` has actually moved, Docker's layer cache behaves correctly on its own: an unchanged repo reuses its cached clone/dependency layers (fast rebuild), while a repo with new commits gets a fresh clone (cache correctly busted). There's no manual cache-busting step anymore. Every tag also doubles as a permanent, human-readable record of exactly what commit was deployed and when — visible directly on GitHub.

This does mean `make up` requires network access to the GitHub API even when just restarting containers with no source changes — by design, so "build" always means "verifiably built from a specific, current commit."

## Running on Synology NAS (Container Manager)

Container Manager has no shell, so `.env` must be a **manually maintained** merge of `.env.backend` + `.env.frontend`, placed in the project folder. One-time setup also requires copying the `deploy/` folder onto the NAS as a sibling of this project's folder (same manual-copy pattern as the `.env.*` files):

1. Copy `.env.backend` and `.env.frontend` onto the NAS (via File Station) with production-appropriate values, including `GIT_AUTH_TOKEN` (with push/write scope — see Prerequisites) in `.env.backend`.
2. Copy the `deploy/` folder onto the NAS as a sibling of this `meal-planner-dockers` project folder.
3. Concatenate `.env.backend` + `.env.frontend` into a single `.env` file in the same folder — this is required for Compose's own variable interpolation.
4. **Whenever you edit `.env.backend` or `.env.frontend`, you must re-merge them into `.env` and redeploy** — Compose does not read the split files on its own, only `.env`. Forgetting this step is exactly what caused a prior outage (backend couldn't reach the database because Compose interpolated empty credentials).

Two ways to deploy from here, both via SSH:

- **Recommended**: `cd` into `deploy/`, run `./tag-release.sh --build` — tags both repos' current `main` and rebuilds/restarts everything in one step, bypassing Container Manager's GUI entirely.
- **GUI-driven alternative**: `cd` into `deploy/`, run `./tag-release.sh` (no `--build`), merge the two lines it writes to `../meal-planner-dockers/.deploy-tags.env` into the NAS's merged `.env`, then in Container Manager: create/open the project pointing at this folder, use `docker-compose.yml`, and click Build.

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
