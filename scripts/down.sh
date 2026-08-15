#!/bin/bash
#
# Tears down the stack: `docker compose down --rmi local`, after sourcing
# .env.backend/.env.frontend (needed for compose's own ${VAR} interpolation).
#
# Usage: ./down.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCKERS_DIR="$SCRIPT_DIR/.."
BACKEND_ENV_FILE="$DOCKERS_DIR/.env.backend"
FRONTEND_ENV_FILE="$DOCKERS_DIR/.env.frontend"

set -a
# shellcheck disable=SC1090
source "$BACKEND_ENV_FILE"
# shellcheck disable=SC1090
source "$FRONTEND_ENV_FILE"
set +a

cd "$DOCKERS_DIR"
docker compose down --rmi local
