.PHONY: up
.PHONY: down

up:
	docker compose build && docker compose up -d

down:
	docker compose down

restart:
	$(MAKE) down && $(MAKE) up
