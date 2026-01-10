#!/bin/bash
#
# god-ralph Stop Hook
#
# This script intercepts Claude's exit attempts and implements the Ralph loop.
# When a Ralph is working on a bead, this hook:
# 1. Checks if there's an active ralph session
# 2. Checks for completion promise in Claude's output
# 3. If not complete, re-injects the prompt to continue iteration
# 4. If complete or max iterations reached, allows exit
#

set -euo pipefail

# Read stop hook input from stdin (JSON with transcript_path)
HOOK_INPUT=$(cat)

# State file location (in project's .claude directory)
STATE_DIR=".claude/god-ralph"
STATE_FILE="$STATE_DIR/ralph-session.json"
LOG_DIR="$STATE_DIR/logs"

# Check if we're in a ralph session
if [[ ! -f "$STATE_FILE" ]]; then
    # No active ralph session, allow normal exit
    exit 0
fi

# Parse state file
if ! STATE=$(cat "$STATE_FILE" 2>/dev/null); then
    echo "Error: Could not read state file" >&2
    exit 0
fi

# Extract session info
BEAD_ID=$(echo "$STATE" | jq -r '.bead_id // empty')
ITERATION=$(echo "$STATE" | jq -r '.iteration // 1')
MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations // 50')
COMPLETION_PROMISE=$(echo "$STATE" | jq -r '.completion_promise // "BEAD COMPLETE"')
WORKTREE_PATH=$(echo "$STATE" | jq -r '.worktree_path // empty')

# Validate iteration and max_iterations are numeric
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid iteration values in state file" >&2
    rm -f "$STATE_FILE"
    exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# Check for completion promise in transcript
PROMISE_FOUND=false
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Extract last assistant message and check for promise tags
    LAST_MESSAGE=$(tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | \
        jq -rs '[.[] | select(.role == "assistant")] | last | .content // empty' 2>/dev/null || echo "")

    if [[ -n "$LAST_MESSAGE" ]]; then
        # Check for <promise>COMPLETION_PROMISE</promise> pattern
        if echo "$LAST_MESSAGE" | grep -qE "<promise>$COMPLETION_PROMISE</promise>"; then
            PROMISE_FOUND=true
        fi
    fi
fi

# Log current iteration
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ralph-$BEAD_ID.log"
echo "[$(date -Iseconds)] Iteration $ITERATION/$MAX_ITERATIONS - Promise found: $PROMISE_FOUND" >> "$LOG_FILE"

# Check if we should exit
if [[ "$PROMISE_FOUND" == "true" ]]; then
    echo "[god-ralph] Bead $BEAD_ID completed! Promise detected." >> "$LOG_FILE"

    # Mark bead as ready for verification
    echo "$STATE" | jq '.status = "completed" | .completed_at = now' > "$STATE_FILE.completed"
    mv "$STATE_FILE.completed" "$STATE_FILE"

    # Allow exit - orchestrator will pick up from here
    exit 0
fi

# Check if max iterations reached
if (( ITERATION >= MAX_ITERATIONS )); then
    echo "[god-ralph] Max iterations ($MAX_ITERATIONS) reached for bead $BEAD_ID" >> "$LOG_FILE"

    # Mark bead as failed
    echo "$STATE" | jq '.status = "failed" | .failure_reason = "max_iterations_reached"' > "$STATE_FILE.failed"
    mv "$STATE_FILE.failed" "$STATE_FILE"

    # Allow exit
    exit 0
fi

# Increment iteration and continue loop
NEW_ITERATION=$((ITERATION + 1))
echo "$STATE" | jq ".iteration = $NEW_ITERATION" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"

# Get the prompt from state
PROMPT=$(echo "$STATE" | jq -r '.prompt // empty')

if [[ -z "$PROMPT" ]]; then
    echo "Error: No prompt found in state file" >&2
    exit 0
fi

# Build the continuation message
CONTINUE_MSG="[god-ralph] Iteration $NEW_ITERATION/$MAX_ITERATIONS for bead $BEAD_ID

To complete this bead, output: <promise>$COMPLETION_PROMISE</promise>
ONLY output the promise when the acceptance criteria are FULLY met.

Continue working on the task:"

# Block exit and re-inject prompt
# Output JSON to block the exit and provide reason (which becomes new input)
cat << EOF
{
  "decision": "block",
  "reason": "$CONTINUE_MSG\n\n$PROMPT"
}
EOF
