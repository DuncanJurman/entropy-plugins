#!/bin/bash
#
# Clean up Ralph worktrees after completion
#
# Usage:
#   cleanup-worktree.sh <bead-id> [--keep-branch]  - Clean single worktree
#   cleanup-worktree.sh --all                       - Clean all completed/failed worktrees
#   cleanup-worktree.sh --status                    - Show worktree status
#

set -euo pipefail

# State directory
STATE_DIR=".claude/god-ralph"
WORKTREES_DIR=".worktrees"

# Function to clean a single worktree
cleanup_single() {
    local bead_id="$1"
    local keep_branch="${2:-}"

    local worktree_path="$WORKTREES_DIR/ralph-$bead_id"
    local branch_name="ralph/$bead_id"

    # Check if worktree exists
    if [[ ! -d "$worktree_path" ]]; then
        echo "[cleanup-worktree] Worktree not found at $worktree_path"
        return 0
    fi

    # Ensure no uncommitted changes
    pushd "$worktree_path" > /dev/null
    if [[ -n "$(git status --porcelain 2>/dev/null || echo '')" ]]; then
        echo "[cleanup-worktree] Warning: Uncommitted changes in $worktree_path"
        git status --short
        echo "[cleanup-worktree] Committing as WIP..."
        git add -A
        git commit -m "WIP: Cleanup commit for $bead_id" || true
    fi
    popd > /dev/null

    # Remove worktree
    echo "[cleanup-worktree] Removing worktree at $worktree_path"
    git worktree remove "$worktree_path" --force 2>/dev/null || rm -rf "$worktree_path"

    # Optionally remove branch
    if [[ "$keep_branch" != "--keep-branch" ]]; then
        echo "[cleanup-worktree] Removing branch $branch_name"
        git branch -D "$branch_name" 2>/dev/null || true
    else
        echo "[cleanup-worktree] Keeping branch $branch_name"
    fi

    # Clean up session state file in main repo (if this bead's session is active)
    local main_state_file="$STATE_DIR/ralph-session.json"
    if [[ -f "$main_state_file" ]]; then
        local active_bead_id
        active_bead_id=$(jq -r '.bead_id // empty' "$main_state_file" 2>/dev/null || echo "")
        if [[ "$active_bead_id" == "$bead_id" ]]; then
            echo "[cleanup-worktree] Removing session state file for $bead_id"
            rm -f "$main_state_file"
        fi
    fi

    echo "[cleanup-worktree] Cleaned up $bead_id"
}

# Function to show status of all worktrees
show_status() {
    echo "=== Ralph Worktree Status ==="
    echo ""

    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "No worktrees directory found."
        return 0
    fi

    local count=0
    for worktree in "$WORKTREES_DIR"/ralph-*; do
        [[ -d "$worktree" ]] || continue
        count=$((count + 1))

        local bead_id
        bead_id=$(basename "$worktree" | sed 's/^ralph-//')
        local state_file="$worktree/.claude/god-ralph/ralph-session.json"

        if [[ -f "$state_file" ]]; then
            local status iteration max_iterations
            status=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")
            iteration=$(jq -r '.iteration // "?"' "$state_file" 2>/dev/null || echo "?")
            max_iterations=$(jq -r '.max_iterations // "?"' "$state_file" 2>/dev/null || echo "?")
            echo "  $bead_id: $status (iteration $iteration/$max_iterations)"
        else
            echo "  $bead_id: no state file"
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "  No worktrees found."
    else
        echo ""
        echo "Total: $count worktree(s)"
    fi
}

# Function to clean all completed/failed worktrees
cleanup_all() {
    echo "=== Cleaning Completed/Failed Worktrees ==="

    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "No worktrees directory found."
        return 0
    fi

    local cleaned=0
    local skipped=0

    for worktree in "$WORKTREES_DIR"/ralph-*; do
        [[ -d "$worktree" ]] || continue

        local bead_id
        bead_id=$(basename "$worktree" | sed 's/^ralph-//')
        local state_file="$worktree/.claude/god-ralph/ralph-session.json"

        if [[ -f "$state_file" ]]; then
            local status
            status=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")

            case "$status" in
                completed|failed)
                    echo ""
                    echo "Cleaning $bead_id (status: $status)..."
                    cleanup_single "$bead_id"
                    cleaned=$((cleaned + 1))
                    ;;
                *)
                    echo "Skipping $bead_id (status: $status)"
                    skipped=$((skipped + 1))
                    ;;
            esac
        else
            # No state file - probably orphaned, clean it
            echo ""
            echo "Cleaning orphaned worktree: $bead_id..."
            cleanup_single "$bead_id"
            cleaned=$((cleaned + 1))
        fi
    done

    echo ""
    echo "=== Summary ==="
    echo "Cleaned: $cleaned"
    echo "Skipped (in progress): $skipped"
}

# Main dispatch
case "${1:-}" in
    --all)
        cleanup_all
        ;;
    --status)
        show_status
        ;;
    --help|-h)
        echo "Usage:"
        echo "  cleanup-worktree.sh <bead-id> [--keep-branch]  - Clean single worktree"
        echo "  cleanup-worktree.sh --all                       - Clean all completed/failed"
        echo "  cleanup-worktree.sh --status                    - Show worktree status"
        ;;
    "")
        echo "Error: Missing argument. Use --help for usage." >&2
        exit 1
        ;;
    *)
        cleanup_single "$1" "${2:-}"
        ;;
esac

echo ""
echo "[cleanup-worktree] Done"
