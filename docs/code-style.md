# Code Style

Conventions actually used in this repo — Dockerfile/Compose conventions are documented in `CONTRIBUTING.md`; the shell-scripting conventions below are reverse-engineered from `scripts/*.sh` (not documented anywhere else), since that's where most of the actual logic in this repo lives.

## Dockerfile / Compose conventions (from `CONTRIBUTING.md`)

| Convention                                                | Where observed                                                                                                                                                                    |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Multi-stage builds                                        | `backend/Dockerfile` (`golang:1.25.3` -> `alpine:3.19`), `frontend/Dockerfile` (`node:26` -> `nginx:alpine`)                                                                      |
| Pinned base image versions, never `:latest`               | `postgres:15`, `golang:1.25.3`, `alpine:3.19` - `frontend`'s runtime stage is the one exception, using the floating `nginx:alpine` tag                                            |
| Non-root runtime user                                     | `backend/Dockerfile` creates `appuser` (uid/gid 1000) and switches to it before `CMD`                                                                                             |
| `.dockerignore` present                                   | repo root `.dockerignore` excludes git files, `.env*`, `.ssh/`, docs, `Makefile`, IDE files                                                                                       |
| Combine `RUN` layers where the steps are one logical unit | the clone-then-verify steps in both Dockerfiles are split into two separate deliberate `RUN`s - cache correctness (see `docs/architecture.md`) matters more here than layer count |
| Clean package caches in the same `RUN`                    | `apk add --no-cache ...` in both `backend/Dockerfile` and `frontend/Dockerfile`                                                                                                   |

## Compose conventions

- Every service defines a `healthcheck`; `backend` and `frontend` both `depends_on` the tier below with `restart: unless-stopped`.
- Two `bridge` networks enforce the isolation described in `docs/architecture.md`; no service is on a network it doesn't need.
- All configuration is environment-driven — no literal values in `docker-compose.yml` beyond internal container ports (`8010`, `5432`, `80`) and the frontend's external port mapping (`5173:80`, not parameterized).

---

## Shell scripting conventions (`scripts/*.sh`)

The six scripts split into two families with different conventions.

### `deploy.sh` / `up.sh` / `down.sh` (compose-orchestration family)

| Convention          | Detail                                                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strict mode         | `set -euo pipefail` at the top of every script in this family                                                                                                                             |
| Path independence   | Standard preamble (below) resolves paths regardless of the caller's working directory                                                                                                     |
| Env loading         | `set -a` / `source` / `set +a` - auto-exports every variable the sourced file defines, not a hand-rolled parser                                                                           |
| Shellcheck          | `# shellcheck disable=SC1090` / `SC1091` precedes every dynamic `source`, acknowledging shellcheck can't statically resolve the path                                                      |
| Shared helpers      | `deploy.sh` and `up.sh` source `scripts/lib.sh` for GitHub API access; `down.sh` doesn't, since it only needs the env files for Compose's `${VAR}` interpolation                          |
| Pre-`lib.sh` checks | File-existence and required-var checks happen before `lib.sh` is sourced, so they can't use its `fail()` helper yet - they inline the same shape by hand: `echo "ERROR: ..." >&2; exit 1` |
| Output convention   | Every script ends with a one-line-per-service summary to stderr (`echo "backend: ${SHA} (${TAG})" >&2`), not stdout - keeps stdout clean for scripting/piping                             |

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCKERS_DIR="$SCRIPT_DIR/.."
```

### `scripts/lib.sh` (shared helpers, sourced — not a standalone script)

| Convention           | Detail                                                                                                                                                                                                                                                                            |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Error helper         | A single `fail()` (`echo "ERROR: $*" >&2; exit 1`) used everywhere once it's loaded                                                                                                                                                                                               |
| No `jq` dependency   | By design - must produce identical behavior on macOS (local) and Synology DSM's shell (NAS), so JSON is parsed with `grep -o` / `sed -E` against GitHub's known response shape                                                                                                    |
| Cross-platform dates | `iso_to_epoch()` tries GNU `date -d` first, falls back to BSD `date -j -f` - same macOS/DSM portability concern                                                                                                                                                                   |
| Return channels      | Globals set by convention rather than passed back: `GH_STATUS`/`GH_BODY` (after `gh_request`), `LATEST_TAG_NAME`/`LATEST_TAG_SHA` (after `get_latest_tag`), `TAG_WAS_NEW` (after `tag_commit_if_needed`) - callers read them immediately, before anything else can overwrite them |
| Named out-var        | `tag_commit_if_needed` takes an explicit `out_var` name and assigns through `printf -v "$out_var"` rather than echoing a value                                                                                                                                                    |
| Cleanup trap         | `trap release_lock EXIT` guarantees the cross-machine tag-minting lock (a throwaway `tag-release-lock` git tag/ref) is released even if the script dies mid-way                                                                                                                   |

### `db-dump.sh` / `db-restore.sh` (database family — noticeably different conventions)

- No `set -euo pipefail` — manual `[ -z "$VAR" ]` checks and `if [ $? -eq 0 ]` after each operation instead of strict mode.
- Env loading uses `export $(grep -v '^#' "$ENV_FILE" | xargs)` rather than `set -a`/`source`/`set +a` — functionally similar, but breaks on values containing spaces or shell metacharacters.
- `db-restore.sh` gates its destructive step behind an explicit `read -p "... [y/N]"` confirmation before running `DROP SCHEMA public CASCADE`.
- Both branch on `ENVIRONMENT` (`LOCAL`, `LOCAL_DOCKER`, `PRODUCTION`) with an identical three-way `if/elif/elif/else "Unknown ENVIRONMENT"` structure, duplicated between the two scripts rather than factored into a shared helper.

---

## Naming

- Scripts: lowercase-with-hyphens (`db-dump.sh`, `db-restore.sh`), matching `CONTRIBUTING.md`'s documented file-naming rule.
- Shell variables: `SCREAMING_SNAKE_CASE` for env vars and script-global state (`BACKEND_SHA`, `GH_STATUS`), `local lower_snake_case` for function-local variables.
- Functions: `snake_case` (`get_latest_tag`, `tag_commit_if_needed`, `resolve_head`).

## Comments

Every script and `lib.sh` opens with a multi-line header comment explaining *why*, not just what — e.g. why `GIT_REF` is a SHA and not a branch, why there's no `jq` dependency, why the lock exists. Several cross-reference specific files in the umbrella repo's `plans/` folder for full design history. This matches `CONTRIBUTING.md`'s stated guidance to explain non-obvious commands and complex configurations, applied consistently in practice.
