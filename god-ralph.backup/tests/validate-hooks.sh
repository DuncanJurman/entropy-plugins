#!/bin/bash
#
# Validation tests for god-ralph hooks
# Run from the god-ralph plugin directory
#
# Usage: ./tests/validate-hooks.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR=$(mktemp -d)
PASS_COUNT=0
FAIL_COUNT=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=========================================="
echo "God-Ralph Hook Validation Tests"
echo "=========================================="
echo ""
echo "Test directory: $TEST_DIR"
echo ""

# Initialize a test git repo
cd "$TEST_DIR"
git init -q
echo "test" > test.txt
git add test.txt
git commit -q -m "Initial commit"

# =============================================================================
# TEST 1: ensure-worktree.sh - Bead ID extraction (strict regex)
# =============================================================================
echo ""
echo "--- Test 1: Bead ID Extraction (Strict Regex) ---"

# Test 1a: Valid bead ID should be extracted
log_info "Testing valid bead ID extraction..."

MOCK_INPUT='{
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "ralph-worker",
    "description": "Ralph worker for beads-abc123",
    "prompt": "Complete bead beads-abc123: Add user settings"
  }
}'

# Capture stdout only (stderr goes to log)
# Need || true because pipefail may trigger on internal hook handling
OUTPUT=$( (echo "$MOCK_INPUT" | "$PLUGIN_ROOT/hooks/ensure-worktree.sh") 2>>"$TEST_DIR/hook.log" ) || true
EXTRACTED_ID=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.updatedInput.bead_id // empty' 2>/dev/null || echo "")

if [[ "$EXTRACTED_ID" == "beads-abc123" ]]; then
    log_pass "Valid bead ID 'beads-abc123' extracted correctly"
else
    log_fail "Valid bead ID extraction" "beads-abc123" "$EXTRACTED_ID"
fi

# Test 1b: Invalid pattern should NOT be extracted (fallback to timestamp)
log_info "Testing invalid pattern rejection..."

MOCK_INPUT_INVALID='{
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "ralph-worker",
    "description": "Ralph worker for user-settings",
    "prompt": "Complete task about user-settings and config-options"
  }
}'

OUTPUT_INVALID=$( (echo "$MOCK_INPUT_INVALID" | "$PLUGIN_ROOT/hooks/ensure-worktree.sh") 2>>"$TEST_DIR/hook.log" ) || true
EXTRACTED_INVALID=$(echo "$OUTPUT_INVALID" | jq -r '.hookSpecificOutput.updatedInput.bead_id // empty' 2>/dev/null || echo "")

# Should get a timestamp-based fallback (ralph-NNNNNNNNNN) not user-settings
if [[ "$EXTRACTED_INVALID" =~ ^ralph-[0-9]+$ ]]; then
    log_pass "Invalid pattern 'user-settings' correctly rejected, got timestamp fallback: $EXTRACTED_INVALID"
elif [[ "$EXTRACTED_INVALID" == "user-settings" ]] || [[ "$EXTRACTED_INVALID" == "config-options" ]]; then
    log_fail "Invalid pattern rejection" "ralph-TIMESTAMP" "$EXTRACTED_INVALID (false positive!)"
else
    log_fail "Invalid pattern rejection" "ralph-TIMESTAMP" "$EXTRACTED_INVALID"
fi

# Clean up worktrees from test 1
git worktree prune 2>/dev/null || true
rm -rf .worktrees 2>/dev/null || true

# =============================================================================
# TEST 2: ensure-worktree.sh - Dual state file creation
# =============================================================================
echo ""
echo "--- Test 2: Dual State File Creation ---"

log_info "Testing state file creation in both locations..."

MOCK_INPUT_DUAL='{
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "ralph-worker",
    "description": "Ralph worker for task-xyz789",
    "prompt": "Complete bead task-xyz789: Fix the bug"
  }
}'

OUTPUT_DUAL=$(echo "$MOCK_INPUT_DUAL" | "$PLUGIN_ROOT/hooks/ensure-worktree.sh" 2>/dev/null || true)

# Check main repo state file exists
if [[ -f ".claude/god-ralph/ralph-session.json" ]]; then
    log_pass "State file created in main repo (.claude/god-ralph/ralph-session.json)"
else
    log_fail "Main repo state file" "exists" "not found"
fi

# Check worktree state file exists
if [[ -f ".worktrees/ralph-task-xyz789/.claude/god-ralph/ralph-session.json" ]]; then
    log_pass "State file created in worktree (.worktrees/ralph-task-xyz789/.claude/god-ralph/)"
else
    log_fail "Worktree state file" "exists" "not found"
fi

# =============================================================================
# TEST 3: ensure-worktree.sh - Prompt stored in JSON
# =============================================================================
echo ""
echo "--- Test 3: Prompt Storage in Session JSON ---"

log_info "Verifying prompt is stored in session JSON..."

if [[ -f ".claude/god-ralph/ralph-session.json" ]]; then
    STORED_PROMPT=$(jq -r '.prompt // empty' .claude/god-ralph/ralph-session.json 2>/dev/null || echo "")

    if [[ -n "$STORED_PROMPT" ]] && [[ "$STORED_PROMPT" != "null" ]]; then
        log_pass "Prompt stored in session JSON (length: ${#STORED_PROMPT} chars)"
    else
        log_fail "Prompt storage" "non-empty prompt" "empty or null"
    fi

    # Check version field
    VERSION=$(jq -r '.version // empty' .claude/god-ralph/ralph-session.json 2>/dev/null || echo "")
    if [[ "$VERSION" == "1" ]]; then
        log_pass "Version field present (version: $VERSION)"
    else
        log_fail "Version field" "1" "$VERSION"
    fi

    # Check completion_promise field
    PROMISE=$(jq -r '.completion_promise // empty' .claude/god-ralph/ralph-session.json 2>/dev/null || echo "")
    if [[ "$PROMISE" == "BEAD COMPLETE" ]]; then
        log_pass "Completion promise field present"
    else
        log_fail "Completion promise" "BEAD COMPLETE" "$PROMISE"
    fi
else
    log_fail "Session JSON" "exists" "not found"
fi

# =============================================================================
# TEST 4: stop-hook.sh - Promise detection with fixed string
# =============================================================================
echo ""
echo "--- Test 4: Promise Detection (Fixed String) ---"

log_info "Testing promise detection with special characters..."

# Create mock transcript with promise
mkdir -p "$TEST_DIR/transcripts"
TRANSCRIPT_FILE="$TEST_DIR/transcripts/test-transcript.jsonl"

# Test 4a: Normal promise should be detected
cat > "$TRANSCRIPT_FILE" << 'TRANSCRIPT'
{"role": "user", "content": "Continue working"}
{"role": "assistant", "content": "I have completed all acceptance criteria.\n\n<promise>BEAD COMPLETE</promise>"}
TRANSCRIPT

# Update session state for stop hook test
cat > ".claude/god-ralph/ralph-session.json" << 'STATE'
{
  "version": 1,
  "bead_id": "task-xyz789",
  "worktree_path": ".worktrees/ralph-task-xyz789",
  "iteration": 5,
  "max_iterations": 50,
  "status": "running",
  "completion_promise": "BEAD COMPLETE",
  "prompt": "Complete the task"
}
STATE

STOP_INPUT="{\"transcript_path\": \"$TRANSCRIPT_FILE\"}"
STOP_OUTPUT=$(echo "$STOP_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>/dev/null; echo "EXIT_CODE:$?")
STOP_EXIT=$(echo "$STOP_OUTPUT" | grep -o 'EXIT_CODE:[0-9]*' | cut -d: -f2)

# Exit code 0 means promise was found and exit allowed
if [[ "$STOP_EXIT" == "0" ]]; then
    log_pass "Normal promise '<promise>BEAD COMPLETE</promise>' detected correctly"
else
    log_fail "Normal promise detection" "exit 0 (promise found)" "exit $STOP_EXIT"
fi

# Test 4b: Promise with regex special chars should work (fixed string match)
log_info "Testing promise with special characters..."

cat > ".claude/god-ralph/ralph-session.json" << 'STATE'
{
  "version": 1,
  "bead_id": "task-xyz789",
  "worktree_path": ".worktrees/ralph-task-xyz789",
  "iteration": 5,
  "max_iterations": 50,
  "status": "running",
  "completion_promise": "DONE [100%]",
  "prompt": "Complete the task"
}
STATE

cat > "$TRANSCRIPT_FILE" << 'TRANSCRIPT'
{"role": "assistant", "content": "All done!\n\n<promise>DONE [100%]</promise>"}
TRANSCRIPT

STOP_OUTPUT2=$(echo "$STOP_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>/dev/null; echo "EXIT_CODE:$?")
STOP_EXIT2=$(echo "$STOP_OUTPUT2" | grep -o 'EXIT_CODE:[0-9]*' | cut -d: -f2)

if [[ "$STOP_EXIT2" == "0" ]]; then
    log_pass "Promise with special chars 'DONE [100%]' detected (fixed string match works)"
else
    log_fail "Special char promise detection" "exit 0" "exit $STOP_EXIT2"
fi

# =============================================================================
# TEST 5: stop-hook.sh - Iteration increment and state sync
# =============================================================================
echo ""
echo "--- Test 5: Iteration Increment and State Sync ---"

log_info "Testing iteration increment on incomplete work..."

# Reset state for incomplete work test
cat > ".claude/god-ralph/ralph-session.json" << 'STATE'
{
  "version": 1,
  "bead_id": "task-xyz789",
  "worktree_path": ".worktrees/ralph-task-xyz789",
  "iteration": 3,
  "max_iterations": 50,
  "status": "running",
  "completion_promise": "BEAD COMPLETE",
  "prompt": "Complete the task"
}
STATE

# Transcript without promise (incomplete)
cat > "$TRANSCRIPT_FILE" << 'TRANSCRIPT'
{"role": "assistant", "content": "Still working on it..."}
TRANSCRIPT

# Run stop hook (should block and increment)
STOP_OUTPUT3=$(echo "$STOP_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>/dev/null || true)

# Check iteration was incremented
NEW_ITERATION=$(jq -r '.iteration' .claude/god-ralph/ralph-session.json 2>/dev/null || echo "")
if [[ "$NEW_ITERATION" == "4" ]]; then
    log_pass "Iteration incremented from 3 to 4"
else
    log_fail "Iteration increment" "4" "$NEW_ITERATION"
fi

# Check block decision was returned (output includes decision + reason)
DECISION=$(echo "$STOP_OUTPUT3" | jq -r '.decision // empty' 2>/dev/null || echo "")
if [[ "$DECISION" == "block" ]]; then
    log_pass "Stop hook returned block decision for incomplete work"
else
    log_fail "Block decision" "block" "$DECISION"
fi

# =============================================================================
# TEST 6: stop-hook.sh - Max iterations reached
# =============================================================================
echo ""
echo "--- Test 6: Max Iterations Exit ---"

log_info "Testing max iterations handling..."

cat > ".claude/god-ralph/ralph-session.json" << 'STATE'
{
  "version": 1,
  "bead_id": "task-xyz789",
  "worktree_path": ".worktrees/ralph-task-xyz789",
  "iteration": 50,
  "max_iterations": 50,
  "status": "running",
  "completion_promise": "BEAD COMPLETE",
  "prompt": "Complete the task"
}
STATE

cat > "$TRANSCRIPT_FILE" << 'TRANSCRIPT'
{"role": "assistant", "content": "Still not done..."}
TRANSCRIPT

STOP_OUTPUT4=$(echo "$STOP_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>/dev/null; echo "EXIT_CODE:$?")
STOP_EXIT4=$(echo "$STOP_OUTPUT4" | grep -o 'EXIT_CODE:[0-9]*' | cut -d: -f2)

if [[ "$STOP_EXIT4" == "0" ]]; then
    log_pass "Max iterations (50/50) allows exit"
else
    log_fail "Max iterations exit" "exit 0" "exit $STOP_EXIT4"
fi

# Check status was updated to failed
STATUS=$(jq -r '.status' .claude/god-ralph/ralph-session.json 2>/dev/null || echo "")
if [[ "$STATUS" == "failed" ]]; then
    log_pass "Status updated to 'failed' on max iterations"
else
    log_fail "Failed status" "failed" "$STATUS"
fi

# =============================================================================
# TEST 7: cleanup-worktree.sh - Status command
# =============================================================================
echo ""
echo "--- Test 7: Cleanup Script Status ---"

log_info "Testing cleanup script --status..."

STATUS_OUTPUT=$("$PLUGIN_ROOT/scripts/cleanup-worktree.sh" --status 2>&1 || true)

if echo "$STATUS_OUTPUT" | grep -q "Ralph Worktree Status"; then
    log_pass "Cleanup script --status runs without error"
else
    log_fail "Cleanup --status" "Status output" "$STATUS_OUTPUT"
fi

# =============================================================================
# TEST 8: Non-ralph-worker agents should NOT get worktree
# =============================================================================
echo ""
echo "--- Test 8: Non-Worker Agent Passthrough ---"

log_info "Testing that non-worker agents skip worktree creation..."

MOCK_INPUT_SCRIBE='{
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "scribe",
    "description": "Update CLAUDE.md",
    "prompt": "Log this learning"
  }
}'

OUTPUT_SCRIBE=$(echo "$MOCK_INPUT_SCRIBE" | "$PLUGIN_ROOT/hooks/ensure-worktree.sh" 2>/dev/null || true)
PERMISSION=$(echo "$OUTPUT_SCRIBE" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || echo "")

if [[ "$PERMISSION" == "allow" ]]; then
    # Check no updatedInput (passthrough)
    UPDATED=$(echo "$OUTPUT_SCRIBE" | jq -r '.hookSpecificOutput.updatedInput // "none"' 2>/dev/null || echo "")
    if [[ "$UPDATED" == "none" ]] || [[ "$UPDATED" == "null" ]]; then
        log_pass "Non-worker agent 'scribe' passed through without worktree"
    else
        log_fail "Non-worker passthrough" "no updatedInput" "got updatedInput"
    fi
else
    log_fail "Non-worker permission" "allow" "$PERMISSION"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review.${NC}"
    exit 1
fi
