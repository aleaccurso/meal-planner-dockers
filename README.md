# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose (with BuildKit)
- Two gitignored files in the root directory:
  - **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `GIT_AUTH_TOKEN` (a raw GitHub personal access token, no `GITHUB_USERNAME` needed), AI keys (`GEMINI_API_KEY`, `CLAUDE_API_KEY`, etc.), SMTP creds.
  - **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`.
  - `GIT_AUTH_TOKEN` is passed to the backend/frontend builds as a build `ARG`, consumed inside the Dockerfiles as a git `http.extraheader` (never a URL) so it never appears in build logs or git's own output — see Security Notes in [`CLAUDE.md`](CLAUDE.md) for why this isn't a BuildKit build secret.
- Compose itself only auto-loads a file literally named **`.env`** for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` and `.env.frontend` into the shell before calling `docker compose`, so no generated `.env` is needed. On the NAS (no shell/Makefile — see below) you must maintain `.env` yourself as a merged copy of the other two files.

## Running on Local Machine

```bash
make up
```

This sources `.env.backend`/`.env.frontend`, builds (fetching latest `main` from both repos), and starts all services. `make down` tears everything down; `make restart` does both.

## Running on Synology NAS (Container Manager)

Container Manager has no shell, so `.env` must be a **manually maintained** merge of `.env.backend` + `.env.frontend`, placed in the project folder:

1. Copy `.env.backend` and `.env.frontend` onto the NAS (via File Station) with production-appropriate values, including `GIT_AUTH_TOKEN` in `.env.backend`.
2. Concatenate `.env.backend` + `.env.frontend` into a single `.env` file in the same folder — this is required for Compose's own variable interpolation.
3. **Whenever you edit `.env.backend` or `.env.frontend`, you must re-merge them into `.env` and redeploy** — Compose does not read the split files on its own, only `.env`. Forgetting this step is exactly what caused a prior outage (backend couldn't reach the database because Compose interpolated empty credentials).
4. In Container Manager:
   - Create a new project pointing at this repository's folder.
   - Use the `docker-compose.yml` file.
5. Build and start the containers.

The frontend will be accessible at `http://<NAS_IP>:5173` and will automatically proxy API calls to the backend container.

The git clone step follows normal Docker layer caching (see Security Notes in [`CLAUDE.md`](CLAUDE.md)), so a rebuild that hits a warm cache may not pick up new commits — removing the container and final image does **not** clear this, since the build cache is stored separately. To force a fresh clone, set `CACHEBUST` to a new value (e.g. a timestamp) in `.env` before building — it's wired into both Dockerfiles' build args specifically to invalidate the clone layer's cache. If that's not available in your setup, prune the builder-stage image/cache for that service before rebuilding instead.

## Stop dockers

```bash
docker compose down
```

Or use the Makefile:

```bash
make down
```
