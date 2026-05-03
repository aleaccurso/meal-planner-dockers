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

if [ "$ENVIRONMENT" = "LOCAL" ]; then
    docker exec -i -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        psql -U "$DB_USER" -d "$DB_NAME" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
        && docker exec -i -e PGPASSWORD="$DB_USER_PASSWORD" "$INSTANCE_NAME" \
        psql -U "$DB_USER" "$DB_NAME" < "$DUMP_FILE"
else
    PGPASSWORD="$DB_USER_PASSWORD" psql -h "127.0.0.1" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
        && PGPASSWORD="$DB_USER_PASSWORD" psql -h "127.0.0.1" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" < "$DUMP_FILE"
fi

if [ $? -eq 0 ]; then
    echo "Restore completed from: $DUMP_FILE"
else
    echo "Restore failed."
    exit 1
fi
