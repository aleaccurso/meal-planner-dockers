.PHONY: up
.PHONY: down

up:
	DOCKER_BUILDKIT=1 docker compose --env-file .env.backend.local --env-file .env.frontend.local build && docker compose --env-file .env.backend.local --env-file .env.frontend.local up -d

down:
	docker compose --env-file .env.backend.local --env-file .env.frontend.local down

restart:
	$(MAKE) down && $(MAKE) up
