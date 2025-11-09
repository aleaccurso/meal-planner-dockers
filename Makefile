.PHONY: up
.PHONY: down

up:
	CACHE_BUST=$(date +%s) DOCKER_BUILDKIT=1 docker compose --env-file .env.local -f docker-compose.local.yml build && docker compose --env-file .env.local -f docker-compose.local.yml up -d

down:
	docker compose --env-file .env.local -f docker-compose.local.yml down

restart:
	$(MAKE) down && $(MAKE) up
