---
description: Run Ralph on a specific bead ID
---

# /god-ralph <bead-id>

Run Ralph on a specific bead, bypassing the orchestrator.

## Usage

```
/god-ralph beads-abc123
```

## Behavior

1. Fetch bead details from beads CLI
2. Set up worktree for isolation
3. Initialize Ralph session
4. Launch Ralph worker
5. Monitor until completion or max iterations

## Execution

```bash
# Get bead details
BEAD_ID="$ARGUMENTS"
if [[ -z "$BEAD_ID" ]]; then
  echo "Usage: /god-ralph <bead-id>"
  exit 1
fi

# Verify bead exists
if ! bd show "$BEAD_ID" > /dev/null 2>&1; then
  echo "Error: Bead $BEAD_ID not found"
  exit 1
fi

# Get bead info
BEAD_INFO=$(bd show "$BEAD_ID" --json)
TITLE=$(echo "$BEAD_INFO" | jq -r '.title')
DESCRIPTION=$(echo "$BEAD_INFO" | jq -r '.description')

echo "[god-ralph] Running Ralph on bead: $BEAD_ID"
echo "[god-ralph] Title: $TITLE"
```

## Worktree Setup

```bash
# Create worktree
WORKTREE_PATH=".worktrees/ralph-$BEAD_ID"
BRANCH_NAME="ralph/$BEAD_ID"

git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>/dev/null || {
  echo "[god-ralph] Worktree already exists, reusing"
}
```

## Session Initialization

```bash
# Create state directory in worktree
mkdir -p "$WORKTREE_PATH/.claude/god-ralph"

# Get ralph_spec from bead comments (temporary until schema supports it)
RALPH_SPEC=$(bd comments "$BEAD_ID" --json | jq -r '.[] | select(.text | startswith("ralph_spec:")) | .text')

# Parse or use defaults
COMPLETION_PROMISE="BEAD COMPLETE"
MAX_ITERATIONS=50

# Create session file
cat > "$WORKTREE_PATH/.claude/god-ralph/ralph-session.json" << EOF
{
  "bead_id": "$BEAD_ID",
  "title": "$TITLE",
  "iteration": 1,
  "max_iterations": $MAX_ITERATIONS,
  "completion_promise": "$COMPLETION_PROMISE",
  "worktree_path": "$WORKTREE_PATH",
  "status": "running",
  "started_at": "$(date -Iseconds)",
  "prompt": "Complete the following bead:\n\nTitle: $TITLE\nDescription: $DESCRIPTION\n\nWork in the worktree at $WORKTREE_PATH.\nCommit your progress frequently.\nWhen ALL acceptance criteria are met, output: <promise>$COMPLETION_PROMISE</promise>"
}
EOF
```

## Ralph Launch

Launch Ralph worker using Task tool:

```
Task(
  subagent_type="general-purpose",
  prompt="You are a Ralph worker. Complete bead $BEAD_ID.

Title: $TITLE
Description: $DESCRIPTION

Work in: $WORKTREE_PATH
Branch: $BRANCH_NAME

Follow the ralph-worker agent guidelines.
When complete, output: <promise>BEAD COMPLETE</promise>",
  description="Ralph worker for $BEAD_ID"
)
```

## Arguments

- `--max-iterations N`: Override max iterations (default: 50)
- `--no-worktree`: Run in current directory (no isolation)
- `--dry-run`: Show what would be done without executing

## Output

```
[god-ralph] Running Ralph on bead: beads-abc123
[god-ralph] Title: Add user settings API
[god-ralph] Setting up worktree at .worktrees/ralph-beads-abc123
[god-ralph] Created branch: ralph/beads-abc123
[god-ralph] Launching Ralph worker...

[ralph:beads-abc123] Iteration 1/50 - Reading bead spec
[ralph:beads-abc123] Iteration 2/50 - Creating endpoint
[ralph:beads-abc123] Iteration 3/50 - Adding tests
...
[ralph:beads-abc123] ✓ Completed at iteration 8

[god-ralph] Merging ralph/beads-abc123 to main...
[god-ralph] Running verification...
[god-ralph] ✓ All acceptance criteria passed
[god-ralph] Closing bead beads-abc123
[god-ralph] Done!
```

## References

- [BEAD_SPEC.md](../skills/god-ralph/references/BEAD_SPEC.md) - Ralph-ready bead format specification
- [ralph-worker.md](../agents/ralph-worker.md) - Ralph worker agent definition

## Notes

- Use this for running a single bead manually
- For full autonomous execution, use `/god-ralph start`
- Worktrees are cleaned up after completion
- Progress is saved if interrupted
