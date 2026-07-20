# Contributing to Meal Planner Dockers

Thank you for your interest in contributing to the Meal Planner Docker setup! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Code Style Guidelines](#code-style-guidelines)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Docker Development](#docker-development)
- [Testing](#testing)
- [Getting Help](#getting-help)

## Getting Started

### Prerequisites

- **Docker** (version 20.10 or higher)
- **Docker Compose** (version 2.0 or higher)
- **Git**
- **Make** (optional, for using Makefile commands)
- A GitHub account with access to the repositories:
  - `aleaccurso/meal-planner-backend`
  - `aleaccurso/meal-planner`

### Environment Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd meal-planner-dockers
   ```

2. **Create the env files**

   This repo splits env vars by service. Create these two gitignored files in the root directory:

   ```env
   # .env.backend
   ENVIRONMENT=LOCAL
   JWT_SECRET=your_jwt_secret
   DB_USER=postgres
   DB_USER_PASSWORD=your_password
   DB_NAME=meal_planner
   DB_PORT=5432
   DB_DATA_PATH=./data/postgres
   BACKEND_PORT=8010
   AUTH_CONFIG_PATH=./auth-config.json
   INSTANCE_NAME=meal-planner-db
   DB_DUMPS_FOLDER=./dumps
   USERS_AVATAR_FOLDER=./avatars
   RECIPES_IMAGES_FOLDER=./recipe-images
   GIT_AUTH_TOKEN=your_github_personal_access_token
   # plus AI keys (GEMINI_API_KEY, CLAUDE_API_KEY, ...) and SMTP creds
   ```

   ```env
   # .env.frontend
   API_BASE_URL=/api
   USERS_AVATAR_FOLDER=./avatars
   RECIPES_IMAGES_FOLDER=./recipe-images
   # plus FIREBASE_* vars
   ```

   `GIT_AUTH_TOKEN` (no `GITHUB_USERNAME` needed) is passed to the backend/frontend builds as a build `ARG`, used only in each Dockerfile's discarded builder stage, and passed to `git clone` via an HTTP header — never a URL — so it never appears in build logs or image layers of the final image.

   **Important**: Never commit either of these files to the repository. They contain sensitive information.

   Compose itself still needs a file literally named `.env` for its own `${VAR}` interpolation (build args, ports, volumes) — `make up`/`make down` handle this locally by sourcing `.env.backend` and `.env.frontend` into the shell before invoking `docker compose`, so you don't need to create `.env` by hand for local dev. (Manually merging into `.env` is only required for the NAS/Container Manager deployment — see the root README.)

## Development Setup

### Starting the Application

Use the Makefile commands:

```bash
# Build and start all services
make up

# Stop all services
make down

# Restart all services
make restart
```

Or use Docker Compose directly:

```bash
# Build and start
docker compose build && docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# View logs for a specific service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f db
```

### Accessing the Services

- **Frontend**: http://localhost:${FRONTEND_PORT}
- **Backend API**: http://localhost:${BACKEND_PORT}
- **Database**: localhost:${DB_PORT}

## Project Structure

```
meal-planner-dockers/
├── backend/
│   └── Dockerfile          # Backend service Dockerfile
├── frontend/
│   ├── Dockerfile          # Frontend service Dockerfile
│   └── nginx.conf          # Nginx configuration for frontend
├── db/
│   └── Dockerfile          # Database service Dockerfile
├── docker-compose.yml      # Main Docker Compose configuration
├── Makefile                # Convenience commands
├── .env.backend            # Backend env vars incl. GIT_AUTH_TOKEN (not in git)
├── .env.frontend           # Frontend env vars (not in git)
└── README.md               # Project documentation
```

### Service Architecture

- **db**: PostgreSQL database service
- **backend**: Go backend API service (clones from GitHub during build)
- **frontend**: React frontend service served by Nginx (clones from GitHub during build)

## Code Style Guidelines

### Dockerfile Best Practices

- Use multi-stage builds to minimize image size
- Use specific version tags for base images (e.g., `golang:1.25.3` not `golang:latest`)
- Combine RUN commands to reduce layers when appropriate
- Use `.dockerignore` files to exclude unnecessary files
- Run containers as non-root users when possible
- Clean up package manager caches in the same RUN command

### Docker Compose Guidelines

- Use environment variables for configuration
- Define health checks for services
- Use proper network isolation
- Set appropriate restart policies
- Use volumes for persistent data

### File Naming

- Use lowercase with hyphens for file names: `docker-compose.yml`
- Use descriptive names for scripts and configuration files

### Comments

- Add comments to explain non-obvious Dockerfile commands
- Document environment variables and their purposes
- Explain complex configurations in docker-compose.yml

## Commit Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>([optional scope]): <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

### Examples

```
feat(docker): add health check for backend service
fix(nginx): resolve API proxy configuration issue
docs: update README with environment variable examples
style(dockerfile): improve formatting and comments
refactor(compose): simplify network configuration
chore: update base image versions
```

## Pull Request Process

1. **Create a feature branch**

   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes**

   - Follow the code style guidelines
   - Update documentation if needed
   - Test your changes locally

3. **Test your changes**

   ```bash
   # Rebuild and restart services
   make restart

   # Verify services are running
   docker compose ps

   # Check logs for errors
   docker compose logs
   ```

4. **Commit your changes**

   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push to your fork**

   ```bash
   git push origin feat/your-feature-name
   ```

6. **Create a Pull Request**
   - Use a clear and descriptive title
   - Describe what changes were made and why
   - Include any relevant context or screenshots
   - Link related issues if applicable

### PR Requirements

- [ ] Code follows the style guidelines
- [ ] Self-review completed
- [ ] Services build and run successfully
- [ ] Documentation updated (if needed)
- [ ] No sensitive information committed (check for `.env` files, tokens, etc.)
- [ ] Commit messages follow the convention

## Docker Development

### Building Individual Services

```bash
# Build backend only
docker compose build backend

# Build frontend only
docker compose build frontend

# Build database only
docker compose build db
```

### Debugging

#### Viewing Container Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f db
```

#### Executing Commands in Containers

```bash
# Backend container
docker compose exec backend sh

# Frontend container
docker compose exec frontend sh

# Database container
docker compose exec db psql -U postgres -d meal_planner
```

#### Rebuilding After Changes

If you modify Dockerfiles or docker-compose.yml:

```bash
# Rebuild without cache
docker compose build --no-cache

# Rebuild and restart
make restart
```

### Common Issues

#### Build Failures

- **GitHub authentication errors**: Verify `GIT_AUTH_TOKEN` is set in `.env.backend` and contains a valid token
- **Port conflicts**: Check if ports 5173, 8010, or 5432 are already in use
- **Permission errors**: Ensure Docker has proper permissions

#### Container Startup Issues

- **Database not ready**: Backend depends on database, ensure it's healthy before starting backend
- **Network issues**: Verify networks are created: `docker network ls`
- **Volume issues**: Check volume paths and permissions

## Testing

### Manual Testing

1. **Start all services**

   ```bash
   make up
   ```

2. **Verify services are running**

   ```bash
   docker compose ps
   ```

3. **Check service health**

   ```bash
   # Database health check
   docker compose exec db pg_isready -U postgres

   # Backend health (if health endpoint exists)
   curl http://localhost:8010/health

   # Frontend accessibility
   curl http://localhost:5173
   ```

4. **Test the application**

   - Access frontend at http://localhost:5173
   - Verify API calls work through the frontend
   - Check backend logs for API requests

## Getting Help

### Resources

- **Documentation**: Check the README.md for setup instructions
- **Docker Documentation**: https://docs.docker.com/
- **Docker Compose Documentation**: https://docs.docker.com/compose/

### Support

If you need help:

1. Check existing issues for similar problems
2. Review the codebase and documentation
3. Create an issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Docker version, etc.)

### Common Questions

**Q: How do I update the backend/frontend code?**
A: The Dockerfiles clone from GitHub during build. Update the code in the respective repositories, then rebuild the containers.

**Q: How do I change environment variables?**
A: Update `.env.backend`/`.env.frontend` and restart the services with `make restart`. (On the NAS, also re-merge `.env` — see the root README.)

**Q: How do I access the database directly?**
A: Use `docker compose exec db psql -U postgres -d meal_planner` or connect from a database client to `localhost:5432`.

**Q: Can I develop locally without Docker?**
A: This repository is specifically for Docker deployment. For local development, use the individual frontend and backend repositories.

## Code of Conduct

Please note that this project follows a Code of Conduct. By participating, you are expected to uphold this code.

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Meal Planner Dockers! 🐳


