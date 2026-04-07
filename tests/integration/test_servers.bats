#!/usr/bin/env bats
# Integration tests — run against started servers via tests/integration/run.sh
#
# Requires:
#   - rcon-cli on PATH (install: go install github.com/itzg/rcon-cli@latest)
#   - Servers running via docker-compose.test.yml with project-name mc-integration
#
# Environment (defaults match docker-compose.test.yml):
#   TEST_RCON_PASSWORD       (default: integration-test-rcon-pw)
#   TEST_SURVIVAL_PORT       RCON port for survival  (default: 25675)
#   TEST_CREATIVE_PORT       RCON port for creative  (default: 25676)
#   TEST_SURVIVAL_GAME_PORT  game port for survival  (default: 25665)
#   TEST_CREATIVE_GAME_PORT  game port for creative  (default: 25666)
#   TEST_MC_VERSION          expected MC version     (default: 1.21.4)

: "${TEST_RCON_PASSWORD:=integration-test-rcon-pw}"
: "${TEST_SURVIVAL_PORT:=25675}"
: "${TEST_CREATIVE_PORT:=25676}"
: "${TEST_SURVIVAL_GAME_PORT:=25665}"
: "${TEST_CREATIVE_GAME_PORT:=25666}"
: "${TEST_MC_VERSION:=1.21.4}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

rcon_run() {
  local host="$1" port="$2" cmd="$3"
  local out rc
  # Capture output and exit code separately so the | sed pipe doesn't mask failures
  out=$(rcon-cli --host "$host" --port "$port" --password "$TEST_RCON_PASSWORD" "$cmd" 2>&1)
  rc=$?
  echo "$out" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
  return $rc
}

rcon_survival() { rcon_run localhost "$TEST_SURVIVAL_PORT" "$1"; }
rcon_creative() { rcon_run localhost "$TEST_CREATIVE_PORT" "$1"; }

port_open() {
  nc -z -w3 localhost "$1"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

setup_file() {
  command -v rcon-cli >/dev/null 2>&1 || {
    echo "rcon-cli not found. Install with: go install github.com/itzg/rcon-cli@latest" >&2
    exit 1
  }
}

# ---------------------------------------------------------------------------
# TCP port reachability
# ---------------------------------------------------------------------------

@test "survival game port is reachable" {
  port_open "$TEST_SURVIVAL_GAME_PORT"
}

@test "creative game port is reachable" {
  port_open "$TEST_CREATIVE_GAME_PORT"
}

@test "survival RCON port is reachable" {
  port_open "$TEST_SURVIVAL_PORT"
}

@test "creative RCON port is reachable" {
  port_open "$TEST_CREATIVE_PORT"
}

# ---------------------------------------------------------------------------
# RCON authentication + core server state
# ---------------------------------------------------------------------------

@test "survival RCON authenticates and responds to 'list'" {
  run rcon_survival "list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"players online"* ]]
}

@test "creative RCON authenticates and responds to 'list'" {
  run rcon_creative "list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"players online"* ]]
}

@test "survival reports correct MC version" {
  run rcon_survival "version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_MC_VERSION"* ]]
}

@test "creative reports correct MC version" {
  run rcon_creative "version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_MC_VERSION"* ]]
}

@test "survival is running Paper" {
  run rcon_survival "version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Paper"* ]]
}

@test "creative is running Paper" {
  run rcon_creative "version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Paper"* ]]
}

# ---------------------------------------------------------------------------
# Plugin loading — both servers carry the same production plugin set
# ---------------------------------------------------------------------------

check_plugins_loaded() {
  local rcon_fn="$1"; shift
  local output
  output=$("$rcon_fn" "plugins")

  for plugin in "$@"; do
    if [[ "$output" != *"$plugin"* ]]; then
      echo "Plugin not found in 'plugins' output: $plugin"
      echo "Full output: $output"
      return 1
    fi
  done
}

@test "survival has all expected plugins loaded" {
  check_plugins_loaded rcon_survival \
    "AdvancedSensitiveWords" \
    "AdvancedTeleport" \
    "CoreProtect" \
    "GriefPrevention" \
    "LuckPerms" \
    "Multiverse-Core" \
    "Multiverse-Portals" \
    "Vault" \
    "ViaVersion" \
    "WorldEdit" \
    "WorldGuard"
}

@test "creative has all expected plugins loaded" {
  check_plugins_loaded rcon_creative \
    "AdvancedSensitiveWords" \
    "AdvancedTeleport" \
    "CoreProtect" \
    "GriefPrevention" \
    "LuckPerms" \
    "Multiverse-Core" \
    "Multiverse-Portals" \
    "Vault" \
    "ViaVersion" \
    "WorldEdit" \
    "WorldGuard"
}

# ---------------------------------------------------------------------------
# Multiverse-Core
# ---------------------------------------------------------------------------

@test "survival Multiverse has at least one loaded world" {
  run rcon_survival "mv list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"world"* ]]
}

@test "creative Multiverse has at least one loaded world" {
  run rcon_creative "mv list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"world"* ]]
}

# ---------------------------------------------------------------------------
# LuckPerms
# ---------------------------------------------------------------------------

# LuckPerms does not forward command output to RCON senders; status 0 confirms
# the plugin is loaded and handling the command without error.
@test "survival LuckPerms responds to info command" {
  run rcon_survival "lp info"
  [ "$status" -eq 0 ]
}

@test "creative LuckPerms responds to info command" {
  run rcon_creative "lp info"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# WorldGuard
# ---------------------------------------------------------------------------

@test "survival WorldGuard reports its version" {
  run rcon_survival "wg version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WorldGuard"* ]]
}

@test "creative WorldGuard reports its version" {
  run rcon_creative "wg version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WorldGuard"* ]]
}

# ---------------------------------------------------------------------------
# WorldEdit
# ---------------------------------------------------------------------------

@test "survival WorldEdit reports its version" {
  run rcon_survival "we version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WorldEdit"* ]]
}

@test "creative WorldEdit reports its version" {
  run rcon_creative "we version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WorldEdit"* ]]
}

# ---------------------------------------------------------------------------
# CoreProtect
# ---------------------------------------------------------------------------

# "co status" returns no output via RCON; bare "co" returns the help text which
# includes "CoreProtect", confirming the plugin is loaded and responsive.
@test "survival CoreProtect responds to co command" {
  run rcon_survival "co"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CoreProtect"* ]]
}

@test "creative CoreProtect responds to co command" {
  run rcon_creative "co"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CoreProtect"* ]]
}

# ---------------------------------------------------------------------------
# ViaVersion
# ---------------------------------------------------------------------------

@test "survival ViaVersion reports supported protocol versions" {
  run rcon_survival "viaversion version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ViaVersion"* ]]
}

@test "creative ViaVersion reports supported protocol versions" {
  run rcon_creative "viaversion version"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ViaVersion"* ]]
}

# ---------------------------------------------------------------------------
# GriefPrevention
# ---------------------------------------------------------------------------

@test "survival GriefPrevention responds to help command" {
  run rcon_survival "gphelp"
  [ "$status" -eq 0 ]
}

@test "creative GriefPrevention responds to help command" {
  run rcon_creative "gphelp"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Whitelist (shared-config mount)
# ---------------------------------------------------------------------------

@test "survival whitelist is accessible via RCON" {
  run rcon_survival "whitelist list"
  [ "$status" -eq 0 ]
}

@test "creative whitelist is accessible via RCON" {
  run rcon_creative "whitelist list"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Gamerules
# ---------------------------------------------------------------------------

@test "survival gamerule keepInventory is accessible" {
  run rcon_survival "gamerule keepInventory"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keepInventory"* ]]
}

@test "creative gamerule keepInventory is accessible" {
  run rcon_creative "gamerule keepInventory"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keepInventory"* ]]
}
