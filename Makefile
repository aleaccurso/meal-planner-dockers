.PHONY: up
.PHONY: down

up:
	CACHE_BUST=$$(date +%s) DOCKER_BUILDKIT=1 docker compose build && docker compose up -d

down:
	CACHE_BUST=$$(date +%s) docker compose down

restart:
	$(MAKE) down && $(MAKE) up
