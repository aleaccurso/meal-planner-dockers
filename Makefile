.PHONY: up
.PHONY: down
.PHONY: restart
.PHONY: check-env
.PHONY: db-dump
.PHONY: db-restore

check-env:
	@test -f .env.backend || (echo "ERROR: .env.backend not found" && exit 1)
	@test -f .env.frontend || (echo "ERROR: .env.frontend not found" && exit 1)
	@test -f .github_token.secret || (echo "ERROR: .github_token.secret not found" && exit 1)

up: check-env
	set -a; . ./.env.backend; . ./.env.frontend; set +a; \
	docker compose build && docker compose up -d

down: check-env
	set -a; . ./.env.backend; . ./.env.frontend; set +a; \
	docker compose down --rmi local

restart:
	$(MAKE) down && $(MAKE) up

db-dump:
	./scripts/db-dump.sh

db-restore:
	./scripts/db-restore.sh
