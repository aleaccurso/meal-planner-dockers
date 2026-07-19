# meal-planner-dockers

Docker Compose setup for deploying the Meal Planner application (frontend + backend + database).

## Prerequisites

- Docker and Docker Compose (with BuildKit)
- Three gitignored files in the root directory:
  - **`.env.backend`** — `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, AI keys (`GEMINI_API_KEY`, `CLAUDE_API_KEY`, etc.), SMTP creds.
  - **`.env.frontend`** — `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`.
  - **`.github_token.secret`** — a raw GitHub personal access token, and **only** the token (no `GITHUB_USERNAME` needed). Used as a Docker BuildKit build secret to authenticate the `ADD <git-url>` clone steps in the Dockerfiles — never embedded in a URL or image layer. **The file must not have a trailing newline** — BuildKit passes the file's raw bytes as the token, so a trailing `\n` (which editors and `echo`/File Station often add) silently breaks git auth and the clone fails with `terminal prompts disabled`. Create it with `printf '%s' 'your_token' > .github_token.secret`, not `echo`.
- Compose itself only auto-loads a file literally named **`.env`** for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Locally, `make up`/`make down` source `.env.backend` and `.env.frontend` into the shell before calling `docker compose`, so no generated `.env` is needed. On the NAS (no shell/Makefile — see below) you must maintain `.env` yourself as a merged copy of the other two files.

## Running on Local Machine

```bash
make up
```

This sources `.env.backend`/`.env.frontend`, builds (fetching latest `main` from both repos), and starts all services. `make down` tears everything down; `make restart` does both.

## Running on Synology NAS (Container Manager)

Container Manager has no shell, so `.env` must be a **manually maintained** merge of `.env.backend` + `.env.frontend`, plus `.github_token.secret`, all placed in the project folder:

1. Copy `.env.backend`, `.env.frontend`, and `.github_token.secret` onto the NAS (via File Station) with production-appropriate values. Double-check `.github_token.secret` has no trailing newline after upload (see note above) — File Station's editor and drag-and-drop from a locally-edited file are both common ways to introduce one.
2. Concatenate `.env.backend` + `.env.frontend` into a single `.env` file in the same folder — this is required for Compose's own variable interpolation.
3. **Whenever you edit `.env.backend` or `.env.frontend`, you must re-merge them into `.env` and redeploy** — Compose does not read the split files on its own, only `.env`. Forgetting this step is exactly what caused a prior outage (backend couldn't reach the database because Compose interpolated empty credentials).
4. In Container Manager:
   - Create a new project pointing at this repository's folder.
   - Use the `docker-compose.yml` file.
5. Build and start the containers.

The frontend will be accessible at `http://<NAS_IP>:5173` and will automatically proxy API calls to the backend container.

Every build (local or in Container Manager) always fetches the latest commit from the `meal-planner-backend`/`meal-planner` `main` branches — the Dockerfiles check GitHub for the latest commit on every build and only skip the rebuild if nothing changed, so there's no need for a "no cache" option (which Container Manager doesn't expose anyway). Just click Build to redeploy the latest code.

## Stop dockers

```bash
docker compose down
```

Or use the Makefile:

```bash
make down
```
