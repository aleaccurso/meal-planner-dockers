# Recommendations

Gaps below were checked directly against the repo, not inferred.

## No rollback to an arbitrary older version

`scripts/deploy.sh` always resolves and builds each repo's *current `main` HEAD*; `scripts/up.sh` always resolves and builds each repo's *single latest* tag (`scripts/lib.sh`'s `get_latest_tag` only ever returns the newest `v<YYYY.MM.DD>.<N>`). Neither script takes a parameter — both are documented as `Usage: ./deploy.sh` / `Usage: ./up.sh` with no args. There is no sanctioned way to redeploy a specific *older* tag or SHA if the latest deploy turns out to be bad — the only path is to hand-run `docker compose build --build-arg GIT_REF=<old-sha> <service>` per service and manually manage tags, entirely outside the scripted/documented workflow. Worth adding an optional `GIT_REF`/tag argument to `up.sh` (or a `scripts/rollback.sh`) if rollback is ever needed under pressure.

---

## No CI

No `.github/workflows` directory exists anywhere in the repo. Nothing automatically validates `docker-compose.yml` syntax, Dockerfile syntax, or shell script correctness (e.g. `shellcheck`, `hadolint`, `docker compose config`) on push or PR — the `# shellcheck disable=...` comments in `scripts/*.sh` imply shellcheck is used locally/manually at best, not enforced.

---

## `CONTRIBUTING.md`'s manual build alternative is under-specified

`CONTRIBUTING.md` lists `docker compose build && docker compose up -d` as a manual alternative to `make deploy`/`make up`. Verified against `docker-compose.yml`: the backend/frontend `build.args` reference `${GIT_AUTH_TOKEN:?...}` and `${BACKEND_REPO:?...}`/`${FRONTEND_REPO:?...}` (Compose's required-variable syntax) — so this command hard-fails unless `.env.backend`/`.env.frontend` have already been sourced into the calling shell, which `CONTRIBUTING.md` doesn't state as a prerequisite for this specific command. Even when it does work, it never passes `--build-arg GIT_REF`, so it silently builds each repo's `main` branch unpinned and creates no tag — consistent with the risk `CLAUDE.md` documents elsewhere, but `CONTRIBUTING.md` presents this command as a routine equivalent without that caveat.

---

## Minor version drift (verified, low-impact)

`frontend`'s runtime stage uses the floating `nginx:alpine` tag, the one base image in either Dockerfile not pinned to a specific version — inconsistent with the "pin base images" convention followed everywhere else (`postgres:15`, `golang:1.25.3`, `alpine:3.19`).

---

## No design surface here

This repo has no UI or visual design of its own — `nginx` only serves the already-built static assets produced by the frontend repo's own build (`meal-planner/`), and the only "design"-adjacent file here is `frontend/nginx.conf`, which is routing/caching configuration, not visual design. Visual/design conventions belong in `meal-planner/`'s own docs, not here.
