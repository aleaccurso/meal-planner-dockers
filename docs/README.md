# Documentation

Deployment-focused documentation for `meal-planner-dockers`. For setup/prerequisites see the repo root `README.md`; for the dense cross-cutting summary see the repo root `CLAUDE.md`.

| Doc                  | Covers                                                                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `architecture.md`    | Service topology, network isolation, the clone-at-build-time mechanism, healthchecks, and a decision table for `deploy` vs `up` vs `restart` vs `down` |
| `code-style.md`      | Dockerfile/Compose conventions and the actual shell-scripting conventions used in `scripts/*.sh`                                                       |
| `operations.md`      | Env var split and why, release tagging scheme, db-dump/db-restore, NAS/Container Manager deployment                                                    |
| `recommendations.md` | Verified gaps: no rollback to an older version, no CI, under-specified manual build path, minor version drift                                          |
