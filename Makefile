# Ensure mise shims are on PATH so tool binaries work inside make targets
# (required when make is invoked from editors, CI pre-hooks, or non-login shells)
export PATH := $(HOME)/.local/share/mise/shims:$(PATH)

.PHONY: all test integration-test lint lint-docker validate install-deps

# Run the full local test suite (same checks as CI)
all: lint lint-docker validate test

# ---- BATS unit tests -------------------------------------------------------
test:
	@command -v bats >/dev/null 2>&1 || { echo "bats not found. Run 'mise install'."; exit 1; }
	bats --tap tests/

# ---- Integration tests (requires Docker; starts real servers ~3-4 min) -----
integration-test:
	@command -v rcon-cli >/dev/null 2>&1 || { echo "rcon-cli not found. Run 'mise install'."; exit 1; }
	tests/integration/run.sh

# ---- ShellCheck ------------------------------------------------------------
lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found. Run 'mise install'."; exit 1; }
	shellcheck alerts/alerts.sh world-reset/world-reset.sh

# ---- Hadolint (local binary via mise) -------------------------------------
lint-docker:
	@command -v hadolint >/dev/null 2>&1 || { echo "hadolint not found. Run 'mise install'."; exit 1; }
	hadolint alerts/Dockerfile
	hadolint world-reset/Dockerfile

# ---- docker-compose config validation --------------------------------------
validate:
	@command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 || { echo "docker not found, skipping compose validation"; exit 0; }
	@[ -f .env ] || { \
	  echo "No .env found — copying .env.template for validation..."; \
	  cp .env.template .env.validate_tmp && trap 'rm -f .env.validate_tmp' EXIT; \
	  docker-compose --env-file .env.validate_tmp config > /dev/null && \
	  rm -f .env.validate_tmp; exit 0; }
	docker-compose config > /dev/null

# ---- Install local dev dependencies via mise -------------------------------
install-deps:
	@command -v mise >/dev/null 2>&1 || { \
	  echo "mise not found. Install it first: https://mise.jdx.dev/getting-started.html"; exit 1; }
	mise install
	@echo "Done. Run 'make test' for unit tests, 'make integration-test' for server tests."
