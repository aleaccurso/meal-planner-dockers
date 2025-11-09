.PHONY: up
.PHONY: down

up:
	DOCKER_BUILDKIT=1 docker compose build && docker compose up -d

down:
	docker compose down

restart:
	$(MAKE) down && $(MAKE) up
