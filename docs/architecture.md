# Architecture

`meal-planner-dockers` contains no application source. It composes three services — `db`, `backend`, `frontend` — and clones the actual backend/frontend source from GitHub at image build time.

## Services

| Service    | Base image (build -> runtime)    | Runs as                        | Depends on                            | Healthcheck                          |
| ---------- | -------------------------------- | ------------------------------ | ------------------------------------- | ------------------------------------ |
| `db`       | `postgres:15`                    | postgres                       | -                                     | `pg_isready -U $DB_USER -d $DB_NAME` |
| `backend`  | `golang:1.25.3` -> `alpine:3.19` | `appuser` (non-root, uid 1000) | `db` (`service_healthy`)              | `nc -z localhost 8010`               |
| `frontend` | `node:26` -> `nginx:alpine`      | nginx default                  | `backend` (started, not health-gated) | `wget --spider http://localhost/`    |

Data for `db` is bind-mounted from `${DB_DATA_PATH}` into `/var/lib/postgresql/data`, so it survives container recreation.

---

## Network isolation

Two bridge networks, deliberately kept separate:

```
db ── mealplanner_backend_network ── backend ── mealplanner_app_network ── frontend
```

- `mealplanner_backend_network` — joined by `db` and `backend` only.
- `mealplanner_app_network` — joined by `backend` and `frontend` only.

`frontend` has no route to `db` at all. If the frontend container were ever compromised, it can only reach `backend`, which is the only service allowed to talk to `db`.

---

## Clone-at-build-time mechanism

Both `backend/Dockerfile` and `frontend/Dockerfile` `git init` an empty directory and fetch a single commit from GitHub instead of using a `COPY`'d build context, controlled by two build ARGs:

| Build ARG  | Source                                                                                                | Value                                                |
| ---------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `GIT_REPO` | Interpolated from `BACKEND_REPO` / `FRONTEND_REPO` in the gitignored `.env.backend` / `.env.frontend` | `owner/repo` - never hardcoded in any committed file |
| `GIT_REF`  | Passed on the command line by `scripts/deploy.sh` / `scripts/up.sh` via `--build-arg GIT_REF=<sha>`   | Always a full commit SHA, never a branch or tag name |

Build-time flow, per service:

```
docker compose build --build-arg GIT_REF=<sha> <service>
        │
        ▼
  git init (empty dir)
        │
        ▼
  git fetch --depth 1 origin <sha>   ← GIT_REF baked into this RUN layer's cache key
        │
        ▼
  git checkout FETCH_HEAD
        │
        ▼
  build stage runs → discarded; only build output copied to runtime stage
```

`GIT_REF` is fetched directly rather than via `git clone --branch`, because GitHub's smart HTTP protocol allows fetching any reachable commit by SHA but `--branch` only accepts branch/tag names. Referencing `GIT_REF` inside the `RUN` step makes it part of that layer's cache key: an unchanged ref reuses Docker's cached layers, a changed ref busts the cache and re-clones — no manual cache-busting needed.

`GIT_REF` is intentionally **not** a `docker-compose.yml` variable — it never appears in `args:` in `docker-compose.yml`, only on the scripts' command line. Consequence: a bare `docker compose build` (bypassing `scripts/deploy.sh`/`scripts/up.sh`) falls back to each Dockerfile's own `ARG GIT_REF=main` default and silently builds whatever `main` currently is. This is an accepted, documented risk — `scripts/deploy.sh`/`scripts/up.sh` are the only sanctioned build path.

`GIT_AUTH_TOKEN` authenticates the clone via `git -c http.extraheader=...` (never embedded in the remote URL), so it never appears in build logs or git's own output. See `docs/operations.md` for the full security rationale.

---

## Decision table: which command to run

| Situation                                                                       | Command                     |
| ------------------------------------------------------------------------------- | --------------------------- |
| Changed backend or frontend source and want it live                             | `make deploy`               |
| Just want to restart whatever is already running (no source changes)            | `make up` or `make restart` |
| Changed only `docker-compose.yml`, a `Dockerfile`, or `nginx.conf` in this repo | `make up` or `make restart` |
| Nothing has ever been deployed yet (no tags exist)                              | `make deploy`               |
| Want to tear the stack down                                                     | `make down`                 |
| Want to back up the database                                                    | `make db-dump`              |
| Need to restore the database from the latest dump (destructive)                 | `make db-restore`           |

`make up`/`make restart` still call `docker compose build` (not just `up`), so an edited `Dockerfile`/`docker-compose.yml`/`nginx.conf` is picked up. Use `make deploy` instead only when you also need a fresh backend/frontend source commit or a new release tag. `make up` fails loudly if a repo has no tag yet.

The common mistake this table exists to prevent: **`make up` / `make restart` never rebuild from source.** They rebuild from each repo's *last tagged commit* — the same bits `make deploy` already shipped. If you pushed new commits to `main`, `make up`/`make restart` will not reflect that. Only `make deploy` resolves fresh `main` HEAD SHAs and rebuilds from them.

See `docs/operations.md` for the tagging scheme and `docs/code-style.md` for how the scripts implementing all of this are structured.
