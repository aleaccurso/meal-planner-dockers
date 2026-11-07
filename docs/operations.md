# Operations

## Env var split

Configuration is split into two gitignored files, never committed: `.env.backend` and `.env.frontend`.

| File            | Holds                                                                                                                                                                                                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.env.backend`  | `ENVIRONMENT`, `JWT_SECRET`, `DB_USER`, `DB_USER_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_DATA_PATH`, `BACKEND_PORT`, `AUTH_CONFIG_PATH`, `INSTANCE_NAME`, `DB_DUMPS_FOLDER`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER`, `BACKEND_REPO`, `GIT_AUTH_TOKEN`, AI keys, SMTP creds |
| `.env.frontend` | `API_BASE_URL`, `FIREBASE_*`, `USERS_AVATAR_FOLDER`, `RECIPES_IMAGES_FOLDER` (duplicated - both services need them as build args), `FRONTEND_REPO`                                                                                                                              |

Why it's split rather than one file: `BACKEND_REPO`/`FRONTEND_REPO` are each read only from the file for their own service, so the actual GitHub repo names never appear in any committed file — Dockerfiles and scripts only ever see them via the `GIT_REPO` build ARG at runtime.

### The `.env` gotcha

Docker Compose only auto-loads a file literally named `.env` for its own `${VAR}` interpolation (build args, `ports:`, `volumes:`). Neither `.env.backend` nor `.env.frontend` is that file. All of `make deploy`/`make up`/`make down` (via `scripts/deploy.sh`/`up.sh`/`down.sh`) source both files into the shell *before* invoking `docker compose`, so Compose sees the variables as already-exported shell environment variables — no merged `.env` file is ever generated or required, locally or on the NAS.

This matters because of history: a since-removed Container Manager GUI build path required a manually merged `.env` file, and a past production outage was caused by that merge step being forgotten. The fix was to remove the GUI build path entirely — not to document the manual step more carefully — so SSH + the sanctioned scripts (below) is now the only deployment path, and there is nothing to manually re-merge.

### `GIT_AUTH_TOKEN`

- A raw GitHub personal access token, no username needed, with **push/write** scope on both source repos (not just read).
- Used for two purposes with the same token, by design: `scripts/deploy.sh` uses it to create release tags/refs via the GitHub REST API (`git/tags`, `git/refs`) after a successful deploy; `scripts/up.sh` uses it only for read-only tag lookup. Both scripts read it from `.env.backend`, so there's no separate read-only token to manage.
- Passed to `git` via `-c http.extraheader=...` and to the GitHub API via an `Authorization: Bearer` header — never embedded in a URL — so it never appears in build logs or git's own output.
- A plain build `ARG` (not a BuildKit `build.secrets` secret) because Synology Container Manager's compose build rejects `secrets` under `build:` and doesn't honor `DOCKER_BUILDKIT=1`. Declared only in each Dockerfile's discarded builder stage, so it doesn't end up in the final runtime image — but it does still end up in that builder stage's `docker history`. A documented, accepted tradeoff, not an oversight.

---

## Release tagging

`scripts/deploy.sh` is the only command that creates tags, and only after a successful deploy:

```
resolve main HEAD SHA (GitHub API, per repo)
        │
        ▼
docker compose build --build-arg GIT_REF=<sha> <service>
        │
        ▼
docker compose up -d --wait   ── blocks until every healthcheck passes
        │
        ▼ (only on success)
already tagged at this SHA? ──yes──▶ reuse existing tag
        │no
        ▼
mint next v<YYYY.MM.DD>.<N> tag  (cross-machine lock via scripts/lib.sh)
```

If the build or the health wait fails, the script exits before touching any tags.

What a tag buys you: a permanent, human-readable record on GitHub of exactly which commit was running and when — created only once that commit is confirmed healthy, never before. `scripts/up.sh` reads the latest such tag to restart the same bits without touching `main` or GitHub's write endpoints.

---

## Database backup / restore

| Command           | Script                  | Behavior                                                                                                                                                        |
| ----------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `make db-dump`    | `scripts/db-dump.sh`    | `pg_dump`s the database (connection method depends on `ENVIRONMENT`: `LOCAL`, `LOCAL_DOCKER`, or `PRODUCTION`) to `$DB_DUMPS_FOLDER/${DB_NAME}_<timestamp>.sql` |
| `make db-restore` | `scripts/db-restore.sh` | Restores from the most recent dump in `$DB_DUMPS_FOLDER` - destructive, see below                                                                               |

`db-restore.sh` runs `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` before loading the dump — this permanently deletes all current data in the target database first. It prompts `Are you sure? This will overwrite the current database. [y/N]` and aborts on anything but `y`/`Y`. Treat this the same as any other destructive operation: only run it, or suggest running it, with explicit confirmation from whoever is asking.

It always restores the *latest* dump file by filename glob (`${DB_NAME}_*.sql`, sorted by mtime) — there's no way to pick an older dump without manually renaming/removing newer ones first.

---

## Deploying to the Synology NAS (Container Manager)

Deployment goes through the same scripts as local, over SSH — there is no Container Manager GUI build path (removed after the `.env`-merge outage described above). One-time setup:

1. Copy `.env.backend` and `.env.frontend` onto the NAS (e.g. via File Station) with production-appropriate values, including `GIT_AUTH_TOKEN` and `BACKEND_REPO` in `.env.backend`, `FRONTEND_REPO` in `.env.frontend`.

Then, over SSH, from within `meal-planner-dockers/` (already present wherever the repo is checked out — `scripts/` needs no separate copy step):

```bash
./scripts/deploy.sh   # or: make deploy — always builds+deploys current main HEAD, tags on success
./scripts/up.sh        # or: make up — restart from the last tag, no rebuild from main
```

The frontend is reachable at `http://<NAS_IP>:5173` and proxies `/api/` calls to the backend container internally.
