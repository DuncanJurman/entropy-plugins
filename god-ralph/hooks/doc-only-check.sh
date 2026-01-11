#!/usr/bin/env bash
# Ensure scribe only edits .md files

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -n "$FILE_PATH" ]] && [[ ! "$FILE_PATH" =~ \.md$ ]] && [[ ! "$FILE_PATH" =~ CLAUDE ]]; then
    echo "ERROR: Scribe can only edit .md files, attempted: $FILE_PATH" >&2
    cat << EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "Scribe can only edit documentation files (.md, CLAUDE.md)"
  }
}
EOF
    exit 2
fi

echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
