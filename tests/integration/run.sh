#!/usr/bin/env bash
# tests/integration/run.sh
#
# Brings up the integration test stack, waits for the servers to become
# healthy, runs the BATS integration tests, then tears everything down.
#
# Usage:
#   ./tests/integration/run.sh [bats-extra-args...]
#
# Environment:
#   TEST_MC_VERSION   MC version to test (default: 1.21.4)
#   KEEP_STACK        Set to '1' to leave containers running after tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMPOSE_FILE="$REPO_ROOT/docker-compose.test.yml"
PROJECT_NAME="mc-integration"

# How long to poll for healthy status after compose up (seconds).
# 5-min start_period + plugin downloads on first run = allow up to 9 minutes.
HEALTHY_TIMEOUT=540

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { echo "[integration] $*"; }
fail() { echo "[integration] FAIL: $*" >&2; exit 1; }

# Detect docker compose v2 plugin or fall back to docker-compose v1
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
else
  COMPOSE_CMD=(docker-compose)
fi

check_deps() {
  local missing=()
  for cmd in docker bats rcon-cli nc; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "Missing required tools: ${missing[*]}
  Install bats+rcon-cli : make install-deps
  Install nc            : sudo apt-get install netcat-openbsd"
  fi
}

# Poll a server's RCON 'version' command until it returns a non-empty response.
# Paper's /version triggers an async update-check on first invocation; if RCON
# times out before the check completes, the response is empty.  Once the check
# result is cached, subsequent calls return immediately.
wait_version() {
  local label="$1" port="$2"
  local elapsed=0 out
  log "Waiting for $label RCON 'version' to return non-empty (async update-check warm-up)..."
  while [[ "$elapsed" -lt 120 ]]; do
    out=$(rcon-cli --host localhost --port "$port" \
            --password "${TEST_RCON_PASSWORD:-integration-test-rcon-pw}" \
            version 2>/dev/null || true)
    if [[ -n "$out" ]]; then
      log "$label 'version' is warm (${elapsed}s)"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  log "WARNING: $label 'version' still empty after ${elapsed}s — tests may be flaky"
}

compose() {
  "${COMPOSE_CMD[@]}" \
    -f "$COMPOSE_FILE" \
    --project-name "$PROJECT_NAME" \
    "$@"
}

# Return the container ID for a service in the test stack
container_id() {
  compose ps -q "$1" 2>/dev/null | head -1
}

wait_healthy() {
  local service="$1"
  local elapsed=0
  local cid

  log "Waiting for $service to become healthy (timeout: ${HEALTHY_TIMEOUT}s)..."
  while [[ "$elapsed" -lt "$HEALTHY_TIMEOUT" ]]; do
    cid=$(container_id "$service")
    if [[ -z "$cid" ]]; then
      sleep 10; elapsed=$((elapsed + 10)); continue
    fi

    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "not_found")

    case "$status" in
      healthy)
        log "$service is healthy (${elapsed}s)"
        return 0
        ;;
      unhealthy)
        log "$service became unhealthy — last 50 log lines:"
        docker logs "$cid" --tail 50
        return 1
        ;;
    esac

    sleep 10
    elapsed=$((elapsed + 10))
  done

  cid=$(container_id "$service")
  log "Timeout waiting for $service — last 50 log lines:"
  [[ -n "$cid" ]] && docker logs "$cid" --tail 50
  return 1
}

teardown() {
  if [[ "${KEEP_STACK:-0}" == "1" ]]; then
    log "KEEP_STACK=1 — leaving containers running"
    return
  fi
  log "Tearing down test stack..."
  compose down -v --remove-orphans 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  check_deps

  # Always tear down on exit, even on error
  trap teardown EXIT

  # Clean up any leftover state from a previous stalled run (volumes included)
  # so every run starts with a clean slate.
  log "Cleaning up any leftover stack from a previous run..."
  compose down -v --remove-orphans 2>/dev/null || true

  log "Starting integration test stack (project: $PROJECT_NAME)..."
  log "Using compose command: ${COMPOSE_CMD[*]}"
  compose up -d

  # Wait for both servers in parallel
  wait_healthy "survival-test" &
  local survival_pid=$!
  wait_healthy "creative-test" &
  local creative_pid=$!

  local ok=0
  wait "$survival_pid" || ok=1
  wait "$creative_pid" || ok=1

  if [[ "$ok" -ne 0 ]]; then
    fail "One or more servers did not become healthy — aborting tests"
  fi

  # Pre-warm Paper's async 'version' update-check so the RCON response is
  # cached before the test suite runs (otherwise the first call can time out
  # and return empty, causing the version/Paper tests to flake).
  wait_version "survival-test" "${TEST_SURVIVAL_PORT:-25675}" &
  local survival_version_pid=$!
  wait_version "creative-test" "${TEST_CREATIVE_PORT:-25676}" &
  local creative_version_pid=$!
  wait "$survival_version_pid" || true
  wait "$creative_version_pid" || true

  log "Both servers healthy — running integration tests..."
  log "-----------------------------------------------------------"

  bats --tap "$SCRIPT_DIR/test_servers.bats" "$@"
}

main "$@"
