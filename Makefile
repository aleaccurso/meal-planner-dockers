.PHONY: up
.PHONY: deploy
.PHONY: down
.PHONY: restart
.PHONY: check-env
.PHONY: db-dump
.PHONY: db-restore

check-env:
	@test -f .env.backend || (echo "ERROR: .env.backend not found" && exit 1)
	@test -f .env.frontend || (echo "ERROR: .env.frontend not found" && exit 1)
	@grep -q '^GIT_AUTH_TOKEN=' .env.backend || (echo "ERROR: GIT_AUTH_TOKEN not set in .env.backend" && exit 1)

up: check-env
	./scripts/up.sh

deploy: check-env
	./scripts/deploy.sh

down: check-env
	./scripts/down.sh

restart:
	$(MAKE) down && $(MAKE) up

db-dump:
	./scripts/db-dump.sh

db-restore:
	./scripts/db-restore.sh
