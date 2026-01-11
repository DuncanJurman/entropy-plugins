#!/bin/bash
#
# god-ralph PreToolUse Hook for Task Tool
#
# This hook intercepts Task tool calls to ensure Ralph workers
# are spawned in isolated git worktrees.
#
# Flow:
# 1. Read Task tool input from stdin
# 2. Check if subagent_type requires a worktree (explicit whitelist)
# 3. Extract bead ID from prompt
# 4. Create worktree if needed
# 5. Return updatedInput with worktree_path for Ralph to use
#

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract tool name and input
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input // empty')

# Only process Task tool calls
if [[ "$TOOL_NAME" != "Task" ]]; then
    # Not a Task tool call, allow without modification
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    exit 0
fi

# Get the prompt from Task input
PROMPT=$(echo "$TOOL_INPUT" | jq -r '.prompt // empty')
SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // empty')
DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.description // empty')

# =============================================================================
# TYPE-BASED DISPATCH
# =============================================================================
# Only agents that write code need worktrees for git isolation.
# This is an explicit whitelist - no keyword matching.
#
# To add a new worktree-requiring agent:
# 1. Create the agent in agents/<name>.md
# 2. Add the agent's YAML name to the array below
# 3. Update orchestrator.md to spawn with subagent_type="<name>"
# =============================================================================

WORKTREE_AGENTS=(
    "ralph-worker"    # Ephemeral worker that completes one bead
)

# Check if this subagent_type requires a worktree
NEEDS_WORKTREE=false
for agent in "${WORKTREE_AGENTS[@]}"; do
    if [[ "$SUBAGENT_TYPE" == "$agent" ]]; then
        NEEDS_WORKTREE=true
        break
    fi
done

# Not a worktree-requiring agent, allow without modification
if [[ "$NEEDS_WORKTREE" != "true" ]]; then
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    exit 0
fi

# Extract bead ID from prompt
# Strict pattern: only match known bead prefixes to avoid false positives like "user-settings"
# Supported prefixes: beads, task, bug, feature, fix, epic (add more as needed)
BEAD_ID=$(echo "$PROMPT" | grep -oE '(beads|task|bug|feature|fix|epic)-[a-zA-Z0-9]{3,12}' | head -1 || echo "")

# If no bead ID found, try extracting from description
if [[ -z "$BEAD_ID" ]]; then
    BEAD_ID=$(echo "$DESCRIPTION" | grep -oE '(beads|task|bug|feature|fix|epic)-[a-zA-Z0-9]{3,12}' | head -1 || echo "")
fi

# If still no bead ID, generate a timestamp-based one
if [[ -z "$BEAD_ID" ]]; then
    BEAD_ID="ralph-$(date +%s)"
fi

# Define paths
WORKTREE_PATH=".worktrees/ralph-${BEAD_ID}"
BRANCH_NAME="ralph/${BEAD_ID}"
PROJECT_ROOT=$(pwd)

# Log the operation
LOG_DIR=".claude/god-ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-hook.log"
echo "[$(date -Iseconds)] Creating worktree for bead: $BEAD_ID" >> "$LOG_FILE"

# Create worktree directory parent if needed
mkdir -p "$(dirname "$WORKTREE_PATH")"

# Check if worktree already exists
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "[$(date -Iseconds)] Worktree already exists: $WORKTREE_PATH" >> "$LOG_FILE"
else
    # Create the worktree
    # Redirect both stdout and stderr to log (git outputs "HEAD is now at" to stdout)
    if git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" >>"$LOG_FILE" 2>&1; then
        echo "[$(date -Iseconds)] Created worktree with new branch: $BRANCH_NAME" >> "$LOG_FILE"
    elif git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" >>"$LOG_FILE" 2>&1; then
        echo "[$(date -Iseconds)] Created worktree with existing branch: $BRANCH_NAME" >> "$LOG_FILE"
    else
        echo "[$(date -Iseconds)] ERROR: Failed to create worktree" >> "$LOG_FILE"
        # Allow the Task to proceed anyway, Ralph will detect the issue
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
        exit 0
    fi
fi

# Create state directories in BOTH worktree AND main repo
# - Worktree copy: for Ralph to read (bead ID, iteration count, etc.)
# - Main repo copy: for stop-hook to read (since stop-hook runs from main repo)
mkdir -p "$WORKTREE_PATH/.claude/god-ralph"
mkdir -p ".claude/god-ralph"

# Escape prompt for JSON storage (required for stop-hook re-injection)
ESCAPED_ORIGINAL_PROMPT=$(echo "$PROMPT" | jq -Rs '.')

# Create initial session state JSON
# NOTE: prompt field is critical - stop-hook uses it to re-inject on continuation
STATE_JSON=$(cat << EOF
{
  "version": 1,
  "bead_id": "$BEAD_ID",
  "worktree_path": "$PROJECT_ROOT/$WORKTREE_PATH",
  "branch": "$BRANCH_NAME",
  "iteration": 0,
  "max_iterations": 50,
  "status": "initializing",
  "completion_promise": "BEAD COMPLETE",
  "prompt": $ESCAPED_ORIGINAL_PROMPT,
  "created_at": "$(date -Iseconds)"
}
EOF
)

# Write state to BOTH locations
WORKTREE_STATE_FILE="$WORKTREE_PATH/.claude/god-ralph/ralph-session.json"
MAIN_STATE_FILE=".claude/god-ralph/ralph-session.json"

echo "$STATE_JSON" > "$WORKTREE_STATE_FILE"
echo "$STATE_JSON" > "$MAIN_STATE_FILE"

echo "[$(date -Iseconds)] Created session state in worktree: $WORKTREE_STATE_FILE" >> "$LOG_FILE"
echo "[$(date -Iseconds)] Created session state in main repo: $MAIN_STATE_FILE" >> "$LOG_FILE"

# Build the enhanced prompt with worktree context
WORKTREE_CONTEXT="## Worktree Environment

You are running in an isolated git worktree at: $PROJECT_ROOT/$WORKTREE_PATH
Branch: $BRANCH_NAME
Bead ID: $BEAD_ID

CRITICAL: All your file operations should be relative to this worktree.
Run 'cd $PROJECT_ROOT/$WORKTREE_PATH' before doing any work.
Verify with 'pwd' and 'git branch --show-current'.

---

"

# Prepend worktree context to the original prompt
ENHANCED_PROMPT="${WORKTREE_CONTEXT}${PROMPT}"

# Escape the prompt for JSON
ESCAPED_PROMPT=$(echo "$ENHANCED_PROMPT" | jq -Rs '.')

# Return updated input with worktree path and enhanced prompt
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "prompt": $ESCAPED_PROMPT,
      "worktree_path": "$PROJECT_ROOT/$WORKTREE_PATH",
      "bead_id": "$BEAD_ID"
    }
  }
}
EOF
