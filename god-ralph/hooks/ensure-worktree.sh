#!/bin/bash
#
# god-ralph PreToolUse Hook for Task Tool
#
# This hook intercepts Task tool calls to ensure Ralph workers
# are spawned in isolated git worktrees.
#
# Flow:
# 1. Read Task tool input from stdin
# 2. Check worktree_policy from input (required|optional|none)
# 3. Create worktree if policy requires and bead_id provided
# 4. Return updatedInput with worktree_path for Ralph to use
#
# Worktree Policy:
# - "none"     → Pass through unchanged (no worktree created)
# - "required" → Error if bead_id or worktree_path missing (exit 2)
# - "optional" → Create worktree only if bead_id provided
#

set -euo pipefail

# Cleanup on error - will be set later when WORKTREE_PATH is known
WORKTREE_PATH=""  # Initialize empty, will be set during worktree creation
cleanup_on_error() {
    if [[ -n "$WORKTREE_PATH" ]] && [[ -d "$WORKTREE_PATH" ]]; then
        log_msg "Cleaning up failed worktree: $WORKTREE_PATH" 2>/dev/null || true
        git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || rm -rf "$WORKTREE_PATH"
    fi
}
trap cleanup_on_error ERR

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

# =============================================================================
# EXTRACT INPUT PARAMETERS
# =============================================================================
# New explicit parameter approach - no regex extraction needed

PROMPT=$(echo "$TOOL_INPUT" | jq -r '.prompt // empty')
SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // empty')
DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.description // empty')

# New explicit parameters from input JSON
BEAD_ID=$(echo "$TOOL_INPUT" | jq -r '.bead_id // empty')
WORKTREE_PATH_INPUT=$(echo "$TOOL_INPUT" | jq -r '.worktree_path // empty')
WORKTREE_POLICY=$(echo "$TOOL_INPUT" | jq -r '.worktree_policy // "none"')

# =============================================================================
# TYPE-BASED DISPATCH
# =============================================================================
# Only agents that write code need worktrees for git isolation.
# This is an explicit whitelist - no keyword matching.

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

# =============================================================================
# WORKTREE POLICY HANDLING
# =============================================================================

# Setup logging
LOG_DIR=".claude/god-ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-hook.log"

log_msg() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

log_msg "Processing worktree request: policy=$WORKTREE_POLICY, bead_id=$BEAD_ID"

# Policy: "none" - pass through without creating worktree
if [[ "$WORKTREE_POLICY" == "none" ]]; then
    log_msg "Policy 'none': passing through without worktree"
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    exit 0
fi

# Policy: "required" - error if bead_id or worktree_path missing
if [[ "$WORKTREE_POLICY" == "required" ]]; then
    if [[ -z "$BEAD_ID" ]]; then
        log_msg "ERROR: Policy 'required' but bead_id is missing"
        cat << EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "worktree_policy is 'required' but bead_id is missing. The orchestrator must provide bead_id when spawning ralph-worker agents."
  }
}
EOF
        exit 2
    fi

    if [[ -z "$WORKTREE_PATH_INPUT" ]]; then
        log_msg "ERROR: Policy 'required' but worktree_path is missing"
        cat << EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "worktree_policy is 'required' but worktree_path is missing. The orchestrator must provide worktree_path when spawning ralph-worker agents."
  }
}
EOF
        exit 2
    fi
fi

# Policy: "optional" - create worktree only if bead_id provided
if [[ "$WORKTREE_POLICY" == "optional" ]]; then
    if [[ -z "$BEAD_ID" ]]; then
        log_msg "Policy 'optional' but no bead_id: passing through without worktree"
        echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
        exit 0
    fi
fi

# =============================================================================
# WORKTREE CREATION
# =============================================================================
# At this point we have a valid bead_id and need to create/reuse a worktree

PROJECT_ROOT=$(pwd)

# Use provided worktree_path or construct from bead_id
if [[ -n "$WORKTREE_PATH_INPUT" ]]; then
    WORKTREE_PATH="$WORKTREE_PATH_INPUT"
else
    WORKTREE_PATH=".worktrees/ralph-${BEAD_ID}"
fi

BRANCH_NAME="ralph/${BEAD_ID}"

log_msg "Creating/reusing worktree for bead: $BEAD_ID at $WORKTREE_PATH"

# Create worktree directory parent if needed
mkdir -p "$(dirname "$WORKTREE_PATH")"

# Check if worktree already exists (reuse if present)
if [[ -d "$WORKTREE_PATH" ]]; then
    log_msg "Worktree already exists, reusing: $WORKTREE_PATH"
else
    # Create the worktree - capture error output for diagnostics
    WORKTREE_ERROR=""
    if git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" >>"$LOG_FILE" 2>&1; then
        log_msg "Created worktree with new branch: $BRANCH_NAME"
    elif git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" >>"$LOG_FILE" 2>&1; then
        log_msg "Created worktree with existing branch: $BRANCH_NAME"
    else
        log_msg "ERROR: Failed to create worktree"
        # Capture error details for diagnostic output
        WORKTREE_ERROR=$(git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>&1 || true)
        cat << EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "reason": "Failed to create worktree for bead $BEAD_ID: $WORKTREE_ERROR"
  }
}
EOF
        exit 2
    fi
fi

# =============================================================================
# SESSION STATE SETUP (SYMLINK-BASED)
# =============================================================================
# State lives ONLY in main repo - worktree gets a symlink.
# This ensures single source of truth and avoids sync issues.
# - Main repo: .claude/god-ralph/ralph-session.json (actual file)
# - Worktree: .claude/god-ralph -> symlink to main repo's .claude/god-ralph

# Get the main repo path (handles both worktree and main repo contexts)
MAIN_REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")

# Create state directory in main repo only
mkdir -p "$MAIN_REPO_PATH/.claude/god-ralph"

# Escape prompt for JSON storage (required for stop-hook re-injection)
ESCAPED_ORIGINAL_PROMPT=$(echo "$PROMPT" | jq -Rs '.')

# Create initial session state JSON
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
  "started_at": "$(date -Iseconds)",
  "prompt": $ESCAPED_ORIGINAL_PROMPT
}
EOF
)

# Write state to main repo only
MAIN_STATE_FILE="$MAIN_REPO_PATH/.claude/god-ralph/ralph-session.json"
echo "$STATE_JSON" > "$MAIN_STATE_FILE"
log_msg "Created session state in main repo: $MAIN_STATE_FILE"

# Create symlink in worktree pointing to main repo's state directory
# First ensure .claude directory exists in worktree
mkdir -p "$WORKTREE_PATH/.claude"

# Remove existing god-ralph dir/symlink in worktree if present (to avoid conflicts)
if [[ -e "$WORKTREE_PATH/.claude/god-ralph" || -L "$WORKTREE_PATH/.claude/god-ralph" ]]; then
    rm -rf "$WORKTREE_PATH/.claude/god-ralph"
    log_msg "Removed existing .claude/god-ralph in worktree"
fi

# Create symlink from worktree to main repo's state directory
ln -sf "$MAIN_REPO_PATH/.claude/god-ralph" "$WORKTREE_PATH/.claude/god-ralph"
log_msg "Created symlink: $WORKTREE_PATH/.claude/god-ralph -> $MAIN_REPO_PATH/.claude/god-ralph"

# Verify symlink is working
if [[ -L "$WORKTREE_PATH/.claude/god-ralph" ]] && [[ -f "$WORKTREE_PATH/.claude/god-ralph/ralph-session.json" ]]; then
    log_msg "Symlink verification: SUCCESS - state accessible from both locations"
else
    log_msg "WARNING: Symlink verification failed - state may not be accessible from worktree"
fi

# =============================================================================
# BUILD ENHANCED PROMPT WITH WORKTREE CONTEXT
# =============================================================================

WORKTREE_CONTEXT="## Worktree Environment

You are running in an isolated git worktree at: $PROJECT_ROOT/$WORKTREE_PATH
Branch: $BRANCH_NAME
Bead ID: $BEAD_ID

CRITICAL: All your file operations should be relative to this worktree.
Run 'cd $PROJECT_ROOT/$WORKTREE_PATH' before doing any work.
Verify with 'pwd' and 'git branch --show-current'.

---

"

# Prepend worktree context to the original prompt (keep as raw string)
ENHANCED_PROMPT="${WORKTREE_CONTEXT}${PROMPT}"

# =============================================================================
# RETURN UPDATED INPUT
# =============================================================================
# Use jq --arg for safe JSON construction with single escape at output time.
# This avoids double-escaping issues that occur with heredocs and pre-escaped strings.

jq -n \
  --arg prompt "$ENHANCED_PROMPT" \
  --arg bead_id "$BEAD_ID" \
  --arg worktree_path "$PROJECT_ROOT/$WORKTREE_PATH" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "updatedInput": {
        "prompt": $prompt,
        "bead_id": $bead_id,
        "worktree_path": $worktree_path,
        "working_directory": $worktree_path
      }
    }
  }'
