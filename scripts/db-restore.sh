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

DUMP_FILE=$(ls -t "$DB_DUMPS_FOLDER"/${DB_NAME}_*.sql 2>/dev/null | head -n 1)

if [ -z "$DUMP_FILE" ]; then
    echo "No dump found in $DB_DUMPS_FOLDER"
    exit 1
fi

echo "Restoring '$DB_NAME' from: $DUMP_FILE"
read -p "Are you sure? This will overwrite the current database. [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

if [ "$ENVIRONMENT" = "LOCAL_DOCKER" ]; then
    if [ -z "$INSTANCE_NAME" ]; then
        echo "INSTANCE_NAME is not set in .env.backend file!"
        exit 1
    fi
    docker exec -i -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        psql -U "$DB_USER" -d "$DB_NAME" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
        && docker exec -i -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        psql -U "$DB_USER" "$DB_NAME" < "$DUMP_FILE"
elif [ "$ENVIRONMENT" = "LOCAL" ]; then
    PGPASSWORD="$DB_USER_PASSWORD" psql -h "localhost" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
        && PGPASSWORD="$DB_USER_PASSWORD" psql -h "localhost" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" < "$DUMP_FILE"
elif [ "$ENVIRONMENT" = "PRODUCTION" ]; then
    if [ -z "$HOST" ]; then
        echo "HOST is not set in .env.backend file!"
        exit 1
    fi
    PGPASSWORD="$DB_USER_PASSWORD" psql -h "$HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
        && PGPASSWORD="$DB_USER_PASSWORD" psql -h "$HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" < "$DUMP_FILE"
else
    echo "Unknown ENVIRONMENT: '$ENVIRONMENT'. Expected LOCAL, LOCAL_DOCKER, or PRODUCTION."
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "Restore completed from: $DUMP_FILE"
else
    echo "Restore failed."
    exit 1
fi
