#!/usr/bin/env bats
# Unit tests for world-reset/world-reset.sh

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  export DATA_DIR="$TEST_TMP/data"
  mkdir -p "$DATA_DIR"

  # Required env vars (guards at top of script fire during source)
  export WORLD_TO_RESET="pvp"
  export RCON_HOST="localhost"
  export RCON_PASSWORD="testpass"
  export RESET_INTERVAL_SECONDS="60"

  # Default rcon mock — individual tests override as needed
  rcon() { echo ""; }

  # shellcheck source=../world-reset/world-reset.sh
  source "${BATS_TEST_DIRNAME}/../world-reset/world-reset.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# Startup guards
# ---------------------------------------------------------------------------

@test "script exits when WORLD_TO_RESET is unset" {
  unset WORLD_TO_RESET
  run bash "${BATS_TEST_DIRNAME}/../world-reset/world-reset.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"WORLD_TO_RESET"* ]]
}

@test "script exits when RCON_HOST is unset" {
  unset RCON_HOST
  run bash "${BATS_TEST_DIRNAME}/../world-reset/world-reset.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"RCON_HOST"* ]]
}

@test "script exits when RCON_PASSWORD is unset" {
  unset RCON_PASSWORD
  run bash "${BATS_TEST_DIRNAME}/../world-reset/world-reset.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"RCON_PASSWORD"* ]]
}

# ---------------------------------------------------------------------------
# worldExistsOnDisk
# ---------------------------------------------------------------------------

@test "worldExistsOnDisk returns true when directory exists" {
  mkdir -p "$DATA_DIR/pvp"
  run worldExistsOnDisk "pvp"
  [ "$status" -eq 0 ]
}

@test "worldExistsOnDisk returns false when directory is absent" {
  run worldExistsOnDisk "nonexistent"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# worldExistsInMultiverse
# ---------------------------------------------------------------------------

@test "worldExistsInMultiverse returns true when rcon lists the world" {
  rcon() { echo "pvp pvp (loaded)"; }
  run worldExistsInMultiverse "pvp"
  [ "$status" -eq 0 ]
}

@test "worldExistsInMultiverse returns false when world is not in list" {
  rcon() { echo "other_world other_world (loaded)"; }
  run worldExistsInMultiverse "pvp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist in MultiVerse"* ]]
}

# ---------------------------------------------------------------------------
# initializeTemplate
# ---------------------------------------------------------------------------

@test "initializeTemplate creates a .template copy of the world" {
  mkdir -p "$DATA_DIR/pvp"
  echo "level data" > "$DATA_DIR/pvp/level.dat"
  run initializeTemplate
  [ "$status" -eq 0 ]
  [ -d "$DATA_DIR/pvp.template" ]
  [ -f "$DATA_DIR/pvp.template/level.dat" ]
}

@test "initializeTemplate fails when source world directory is missing" {
  # DATA_DIR/pvp does not exist
  run initializeTemplate
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to create template"* ]]
}

# ---------------------------------------------------------------------------
# checkForOnlinePlayers
# ---------------------------------------------------------------------------

@test "checkForOnlinePlayers returns false (skip reset) when no players are online" {
  rcon() { echo "There are 0 of a max of 20 players online: "; }
  run checkForOnlinePlayers
  [ "$status" -ne 0 ]   # returns 1 → proceed with reset
  [[ "$output" == *"No online players"* ]]
}

@test "checkForOnlinePlayers returns false when online players are in other worlds" {
  call_count=0
  rcon() {
    call_count=$(( call_count + 1 ))
    if [[ "$1" == "list" ]]; then
      echo "There are 1 of a max of 20 players online: Steve"
    elif [[ "$1" == data* ]]; then
      echo 'minecraft:overworld'   # player is in overworld, not pvp
    fi
  }
  run checkForOnlinePlayers
  [ "$status" -ne 0 ]   # no player in pvp → proceed with reset
}

@test "checkForOnlinePlayers returns true when a player is in the target world" {
  rcon() {
    if [[ "$1" == "list" ]]; then
      echo "There are 1 of a max of 20 players online: Steve"
    else
      echo "minecraft:pvp"
    fi
  }
  run checkForOnlinePlayers
  [ "$status" -eq 0 ]   # player found in pvp → skip reset
  [[ "$output" == *"Skipping reset"* ]]
}

# ---------------------------------------------------------------------------
# resetFromTemplate
# ---------------------------------------------------------------------------

@test "resetFromTemplate resets world from template on happy path" {
  # World and template exist on disk; multiverse knows about the world
  mkdir -p "$DATA_DIR/pvp"
  echo "old data" > "$DATA_DIR/pvp/level.dat"
  mkdir -p "$DATA_DIR/pvp.template"
  echo "template data" > "$DATA_DIR/pvp.template/level.dat"

  rcon() { echo "pvp pvp (loaded)"; }   # worldExistsInMultiverse + unload + reload all succeed

  run resetFromTemplate
  [ "$status" -eq 0 ]
  [[ "$output" == *"World has been reset"* ]]
  # Template contents should be present in world dir after reset
  [ -f "$DATA_DIR/pvp/level.dat" ]
  grep -q "template data" "$DATA_DIR/pvp/level.dat"
}

@test "resetFromTemplate auto-creates template on first run" {
  mkdir -p "$DATA_DIR/pvp"
  echo "original data" > "$DATA_DIR/pvp/level.dat"
  # No template yet

  rcon() { echo "pvp pvp (loaded)"; }

  run resetFromTemplate
  [ "$status" -eq 0 ]
  [ -d "$DATA_DIR/pvp.template" ]
  [[ "$output" == *"World has been reset"* ]]
}

@test "resetFromTemplate exits when world is not in Multiverse" {
  mkdir -p "$DATA_DIR/pvp"
  mkdir -p "$DATA_DIR/pvp.template"

  rcon() { echo "other_world other_world (loaded)"; }

  run resetFromTemplate
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "resetFromTemplate exits when world is not on disk" {
  # No disk directory; Multiverse has it
  rcon() { echo "pvp pvp (loaded)"; }

  run resetFromTemplate
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}
