.PHONY: up
.PHONY: down

up:
	CACHE_BUST=$(date +%s) DOCKER_BUILDKIT=1 docker compose --env-file .env.local build && docker compose --env-file .env.local up -d

down:
	docker compose --env-file .env.local down

restart:
	$(MAKE) down && $(MAKE) up
