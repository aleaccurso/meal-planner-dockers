# Use the official PostgreSQL image
FROM postgres:15

# Build arg for port (PostgreSQL default is 5432)
ARG DB_PORT

# The official postgres image automatically uses these environment variables:
# - POSTGRES_USER: Username for the database
# - POSTGRES_PASSWORD: Password for the database user
# - POSTGRES_DB: Name of the database to create
# These will be passed from docker-compose.yml which reads from .env file

# Expose PostgreSQL port (using build arg with default value)
EXPOSE ${DB_PORT}

# The postgres image's default CMD will run automatically
# It will initialize the database using the environment variables
