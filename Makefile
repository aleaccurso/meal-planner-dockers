.PHONY: up
.PHONY: down

up:
	docker compose build --no-cache && docker compose up -d

down:
	docker compose down --volumes --rmi local

restart:
	$(MAKE) down && $(MAKE) up
