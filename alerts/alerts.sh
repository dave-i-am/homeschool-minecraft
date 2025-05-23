#!/bin/bash

# This script monitors a log file for new lines and sends them to a Discord channel via a webhook.

WEBHOOK="${ALERTS_WEBHOOK:?Environment variable ALERTS_WEBHOOK not set}"
FILE="${ALERTS_FILE:?Environment variable ALERTS_FILE not set}"

# Check if the monitored file exists
if [ ! -f "$FILE" ]; then
  echo "Error: File '$FILE' not found."
  exit 1
fi

echo "Monitoring $FILE and sending new lines to Discord..."

tail -n 0 -F "$FILE" | while read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  # Send to Discord via webhook
  curl -s -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$(echo "$line" | sed 's/"/\\"/g')\"}" \
       "$WEBHOOK" > /dev/null
done
