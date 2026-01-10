#!/bin/bash
#
# Clean up a Ralph worktree after completion
#
# Usage: cleanup-worktree.sh <bead-id> [--keep-branch]
#

set -euo pipefail

BEAD_ID="${1:-}"
KEEP_BRANCH="${2:-}"

if [[ -z "$BEAD_ID" ]]; then
    echo "Usage: cleanup-worktree.sh <bead-id> [--keep-branch]" >&2
    exit 1
fi

WORKTREE_PATH=".worktrees/ralph-$BEAD_ID"
BRANCH_NAME="ralph/$BEAD_ID"

# Check if worktree exists
if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo "[cleanup-worktree] Worktree not found at $WORKTREE_PATH"
    exit 0
fi

# Ensure no uncommitted changes
cd "$WORKTREE_PATH"
if [[ -n "$(git status --porcelain)" ]]; then
    echo "[cleanup-worktree] Warning: Uncommitted changes in $WORKTREE_PATH"
    git status --short
    echo "[cleanup-worktree] Committing as WIP..."
    git add -A
    git commit -m "WIP: Cleanup commit for $BEAD_ID" || true
fi
cd - > /dev/null

# Remove worktree
echo "[cleanup-worktree] Removing worktree at $WORKTREE_PATH"
git worktree remove "$WORKTREE_PATH" --force

# Optionally remove branch
if [[ "$KEEP_BRANCH" != "--keep-branch" ]]; then
    echo "[cleanup-worktree] Removing branch $BRANCH_NAME"
    git branch -D "$BRANCH_NAME" 2>/dev/null || true
else
    echo "[cleanup-worktree] Keeping branch $BRANCH_NAME"
fi

echo "[cleanup-worktree] Done"
