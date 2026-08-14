#!/bin/bash
#
# Builds and deploys the actual current `main` HEAD commit of
# meal-planner-backend and meal-planner - always the last commit, never a
# possibly-stale tag. Only after `docker compose up -d --wait` reports every
# service healthy does it tag each deployed commit (reusing the existing
# vYYYY.MM.DD.N tag if that commit is already tagged, minting the next one
# otherwise). If the build or the health wait fails, the script exits before
# any tag is created.
#
# Used identically on this machine (Docker Desktop) and in production
# (Synology NAS, over SSH) - this script lives inside meal-planner-dockers/,
# so it's already present wherever that repo is checked out or pulled, no
# separate copy step needed.
#
# Usage: ./deploy.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCKERS_DIR="$SCRIPT_DIR/.."
BACKEND_ENV_FILE="$DOCKERS_DIR/.env.backend"
FRONTEND_ENV_FILE="$DOCKERS_DIR/.env.frontend"

# Both env files are loaded upfront (not just .env.backend) because
# FRONTEND_REPO/BACKEND_REPO must both be resolved before any build starts -
# BACKEND_REPO belongs with the rest of the backend/deploy config in
# .env.backend, FRONTEND_REPO belongs in .env.frontend.
for f in "$BACKEND_ENV_FILE" "$FRONTEND_ENV_FILE"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: $(basename "$f") not found at $f" >&2
        exit 1
    fi
done
set -a
# shellcheck disable=SC1090
source "$BACKEND_ENV_FILE"
# shellcheck disable=SC1090
source "$FRONTEND_ENV_FILE"
set +a

if [ -z "${GIT_AUTH_TOKEN:-}" ]; then
    echo "ERROR: GIT_AUTH_TOKEN not set in $BACKEND_ENV_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

HEAD_SHA=""
resolve_head() {
    # resolve_head <owner/repo> -> sets HEAD_SHA
    local repo="$1"
    gh_request GET "/repos/${repo}/git/refs/heads/main"
    [ "$GH_STATUS" = "200" ] || fail "could not resolve main HEAD for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"
    HEAD_SHA=$(json_field "$GH_BODY" "sha")
    [ -n "$HEAD_SHA" ] || fail "could not parse main HEAD sha for ${repo}"
}

resolve_head "$BACKEND_REPO"
BACKEND_SHA="$HEAD_SHA"
echo "backend: deploying ${BACKEND_SHA} (main HEAD)" >&2

resolve_head "$FRONTEND_REPO"
FRONTEND_SHA="$HEAD_SHA"
echo "frontend: deploying ${FRONTEND_SHA} (main HEAD)" >&2

cd "$DOCKERS_DIR"

# GIT_REF is deliberately not a docker-compose.yml variable - it's passed
# directly on the build command line per service, so it never needs to be
# exported into the environment or referenced anywhere in the compose file.
docker compose build db
docker compose build --build-arg GIT_REF="$BACKEND_SHA" backend
docker compose build --build-arg GIT_REF="$FRONTEND_SHA" frontend

# --wait blocks until every service with a healthcheck reports healthy (or
# fails/timeouts with a non-zero exit) - nothing below this line runs, and
# no tag is minted, unless the deploy actually succeeded.
docker compose up -d --wait

tag_commit_if_needed "$BACKEND_REPO" "$BACKEND_SHA" BACKEND_TAG
[ "$TAG_WAS_NEW" = "1" ] && BACKEND_TAG="${BACKEND_TAG}*"

tag_commit_if_needed "$FRONTEND_REPO" "$FRONTEND_SHA" FRONTEND_TAG
[ "$TAG_WAS_NEW" = "1" ] && FRONTEND_TAG="${FRONTEND_TAG}*"

# A trailing '*' on the tag means it was newly minted by this run (not a
# pre-existing tag being reused because this commit was already deployed).
echo "backend: ${BACKEND_SHA} (${BACKEND_TAG})" >&2
echo "frontend: ${FRONTEND_SHA} (${FRONTEND_TAG})" >&2
