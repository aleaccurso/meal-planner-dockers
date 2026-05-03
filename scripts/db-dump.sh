#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$INSTANCE_NAME" ]; then
    echo "DB_NAME, DB_USER, or INSTANCE_NAME is not set in .env file!"
    exit 1
fi

if [ -z "$DB_DUMPS_FOLDER" ]; then
    echo "DB_DUMPS_FOLDER is not set in .env file!"
    exit 1
fi

DUMPS_DIR="$DB_DUMPS_FOLDER"
mkdir -p "$DUMPS_DIR"

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
DUMP_FILE="$DUMPS_DIR/${DB_NAME}_${TIMESTAMP}.sql"

if [ "$ENVIRONMENT" = "LOCAL" ]; then
    echo "Dumping local PostgreSQL database '$DB_NAME' from container '$INSTANCE_NAME'..."
    docker exec -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        pg_dump -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
else
    echo "Dumping Cloud SQL database '$DB_NAME'..."
    PGPASSWORD="$DB_USER_PASSWORD" pg_dump \
        -h "127.0.0.1" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
fi

if [ $? -eq 0 ]; then
    echo "Dump saved to: $DUMP_FILE"
else
    echo "Dump failed."
    rm -f "$DUMP_FILE"
    exit 1
fi
