#!/usr/bin/env bash
# Validate compose files after edit
# Used as a PostToolUse hook for Write and Edit tools

INPUT=$(cat /dev/stdin)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only validate compose.yml files under synology/docker/
case "$FILE_PATH" in
  */synology/docker/*/compose.yml)
    COMPOSE_DIR=$(dirname "$FILE_PATH")
    if command -v docker &>/dev/null; then
      OUTPUT=$(docker compose -f "$FILE_PATH" config --quiet 2>&1)
      if [ $? -ne 0 ]; then
        echo "Compose validation failed for $FILE_PATH:"
        echo "$OUTPUT"
        exit 2
      fi
    fi
    ;;
esac

exit 0
