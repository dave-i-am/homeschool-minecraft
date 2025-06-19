#!/bin/bash

if [ -z "$WORLD_TO_RESET" ]; then
  echo "Error: Environment variable WORLD_TO_RESET not set."
  exit 1
fi

if [ -z "$RCON_HOST" ] || [ -z "$RCON_PASSWORD" ]; then
  echo "Error: Environment variables RCON_HOST or RCON_PASSWORD not set."
  exit 1
fi

rcon() {
  rcon-cli --host "$RCON_HOST" --port 25575 --password "$RCON_PASSWORD" "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

worldExistsInMultiverse() {
  rcon "mv list" | grep -q "$1 " && return 0 \
    || { echo "World $1 does not exist in MultiVerse."; return 1; }
}

worldExistsOnDisk() {
  [ -d "/data/$1" ]
}

initializeTemplate() {
  echo "Creating initial template copy of $WORLD_TO_RESET..."
  cp -a "/data/$WORLD_TO_RESET" "/data/$WORLD_TO_RESET.template" || {
    echo "Error: Failed to create template copy."
    exit 1
  }
  echo "Template created successfully."
}

checkForOnlinePlayers() {
  echo "Checking for online players in world $WORLD_TO_RESET..."
  players=$(rcon "list" | sed -n 's/.*players online: //p' | tr -d '\r')
  
  if [[ -n "$players" ]]; then
    echo "Online players found: $players"
    IFS=',' read -ra player_array <<< "$players"
    for player in "${player_array[@]}"; do
      player_trimmed=$(echo "$player" | xargs)
      dimension=$(rcon "data get entity $player_trimmed Dimension" 2>/dev/null)

      if echo "$dimension" | grep -q "$WORLD_TO_RESET"; then
        echo "Player '$player_trimmed' is in world '$WORLD_TO_RESET'. Skipping reset."
        return 0
      fi
    done
  else
    echo "No online players found."
  fi
  return 1
}

resetFromTemplate() {

  for check in worldExistsInMultiverse worldExistsOnDisk; do
    if ! $check "$WORLD_TO_RESET"; then
      echo "Error: World $WORLD_TO_RESET does not exist ($check failed). Exiting."
      exit 1
    fi
  done

  if ! worldExistsOnDisk "$WORLD_TO_RESET.template"; then
    initializeTemplate
  fi

  if ! worldExistsOnDisk "$WORLD_TO_RESET.template"; then
    echo "Error: Template world $WORLD_TO_RESET.template does not exist. Cannot reset."
    exit 1
  fi

  echo "Restoring $WORLD_TO_RESET world from template..."
  echo "Unloading world $WORLD_TO_RESET..."
  rcon "mv unload $WORLD_TO_RESET" || {
    echo "Error: Failed to unload world."
    return 1
  }
  rm -rf "/data/$WORLD_TO_RESET" || {
    echo "Error: Failed to remove world directory."
    return 1
  }

  echo "Copying template files..."
  cp -a "/data/$WORLD_TO_RESET.template" "/data/$WORLD_TO_RESET" || {
    echo "Error: Failed to copy template files."
    return 1
  }

  echo "Reloading..."
  rcon "mv reload" || {
    echo "Error: Failed to reload."
    return 1
  }

  echo "World has been reset."
  return 0
}

while true; do
  echo "--- Checking world state ---"

  if checkForOnlinePlayers; then
    echo "Online players detected in $WORLD_TO_RESET. Skipping reset."
  else
    resetFromTemplate
  fi

  echo "Sleeping for $RESET_INTERVAL_SECONDS seconds..."
  sleep $RESET_INTERVAL_SECONDS
done
