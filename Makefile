.PHONY: up
.PHONY: down

up:
	docker compose build --no-cache && docker compose up -d

down:
	docker compose down --rmi local

restart:
	$(MAKE) down && $(MAKE) up

db-dump:
	./scripts/db-dump.sh

db-restore:
	./scripts/db-restore.sh
