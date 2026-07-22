#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENV_FILE="$SCRIPT_DIR/../.env.backend"

if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo ".env.backend file not found at $ENV_FILE"
    exit 1
fi

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "DB_NAME or DB_USER is not set in .env.backend file!"
    exit 1
fi

if [ -z "$DB_DUMPS_FOLDER" ]; then
    echo "DB_DUMPS_FOLDER is not set in .env.backend file!"
    exit 1
fi

DUMPS_DIR="$DB_DUMPS_FOLDER"
mkdir -p "$DUMPS_DIR"

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
DUMP_FILE="$DUMPS_DIR/${DB_NAME}_${TIMESTAMP}.sql"

if [ "$ENVIRONMENT" = "LOCAL_DOCKER" ]; then
    if [ -z "$INSTANCE_NAME" ]; then
        echo "INSTANCE_NAME is not set in .env.backend file!"
        exit 1
    fi
    echo "Dumping local Docker PostgreSQL database '$DB_NAME' from container '$INSTANCE_NAME'..."
    docker exec -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        pg_dump -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
elif [ "$ENVIRONMENT" = "LOCAL" ]; then
    echo "Dumping local PostgreSQL database '$DB_NAME'..."
    PGPASSWORD="$DB_USER_PASSWORD" pg_dump \
        -h "localhost" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
elif [ "$ENVIRONMENT" = "PRODUCTION" ]; then
    if [ -z "$HOST" ]; then
        echo "HOST is not set in .env.backend file!"
        exit 1
    fi
    echo "Dumping production PostgreSQL database '$DB_NAME' on Synology NAS ($HOST)..."
    PGPASSWORD="$DB_USER_PASSWORD" pg_dump \
        -h "$HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
else
    echo "Unknown ENVIRONMENT: '$ENVIRONMENT'. Expected LOCAL, LOCAL_DOCKER, or PRODUCTION."
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "Dump saved to: $DUMP_FILE"
else
    echo "Dump failed."
    rm -f "$DUMP_FILE"
    exit 1
fi
