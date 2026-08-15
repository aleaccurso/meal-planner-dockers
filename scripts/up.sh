#!/bin/bash
#
# Starts the stack from each repo's most recent existing release tag -
# never touches `main`, never creates a tag. Use this to (re)start
# whatever was last shipped by scripts/deploy.sh without re-triggering a
# fresh build off `main` or minting a new tag.
#
# Fails loudly if either repo has no matching v<YYYY.MM.DD>.<N> tag yet -
# run scripts/deploy.sh first in that case. Both repos' tags are resolved
# up front, before any build starts, so a missing tag never leaves a
# partial build behind.
#
# Usage: ./up.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCKERS_DIR="$SCRIPT_DIR/.."
BACKEND_ENV_FILE="$DOCKERS_DIR/.env.backend"
FRONTEND_ENV_FILE="$DOCKERS_DIR/.env.frontend"

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

get_latest_tag "$BACKEND_REPO"
[ -n "$LATEST_TAG_SHA" ] || fail "no tags found for ${BACKEND_REPO} - run scripts/deploy.sh first"
BACKEND_TAG="$LATEST_TAG_NAME"
BACKEND_SHA="$LATEST_TAG_SHA"

get_latest_tag "$FRONTEND_REPO"
[ -n "$LATEST_TAG_SHA" ] || fail "no tags found for ${FRONTEND_REPO} - run scripts/deploy.sh first"
FRONTEND_TAG="$LATEST_TAG_NAME"
FRONTEND_SHA="$LATEST_TAG_SHA"

cd "$DOCKERS_DIR"

docker compose build db
docker compose build --build-arg GIT_REF="$BACKEND_SHA" backend
docker compose build --build-arg GIT_REF="$FRONTEND_SHA" frontend

docker compose up -d --wait

echo "backend: ${BACKEND_SHA} (${BACKEND_TAG})" >&2
echo "frontend: ${FRONTEND_SHA} (${FRONTEND_TAG})" >&2
