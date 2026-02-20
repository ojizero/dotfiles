#!/usr/bin/env bash
# Block writes to .env files (only .env.sample allowed)
# Used as a PreToolUse hook for Write and Edit tools

INPUT=$(cat /dev/stdin)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Allow .env.sample files
case "$BASENAME" in
  .env.sample|.env.sample.*)
    exit 0
    ;;
  .env|.env.*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Cannot write to .env files — they contain secrets and are git-ignored. Create or update .env.sample instead."}}' | jq .
    exit 0
    ;;
esac

exit 0
