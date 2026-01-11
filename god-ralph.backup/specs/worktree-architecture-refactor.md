# Feature: God-Ralph Worktree Architecture Refactor

## Business Context

The god-ralph plugin enables autonomous parallel development by spawning ephemeral Ralph workers on isolated git worktrees. Current implementation has **reliability issues** that will cause failures in production:

1. **Worktree creation uses heuristics** - bead IDs extracted from prompt text via regex, causing false positives and poor fallback IDs
2. **State files duplicated** across main repo and worktrees with no sync mechanism
3. **Scribe writes to wrong location** - updates CLAUDE.md in main repo while Ralph works in worktree, causing cross-branch drift
4. **Global hooks apply everywhere** - no way to enforce agent-specific policies

Per ClaudeDocs/subagents.md: "Subagents run in separate contexts, so relying on heuristics like strengths across handoffs is unreliable."

This refactor implements **policy-driven, deterministic worktree management** where worktrees are keyed by bead_id and passed explicitly in Task input.

## Technical Approach

### Core Design: worktree_policy Parameter

Add explicit policy parameter to all Task invocations:

```yaml
worktree_policy: "required" | "optional" | "none"
```

- **required**: Hook MUST create worktree, error if bead_id/worktree_path missing
- **optional**: Hook creates worktree if bead_id provided, otherwise continues
- **none**: Hook passes through without modification

### Worktree Keying

Worktrees keyed by `bead_id`, not per-handoff:
- Path: `.worktrees/ralph-{bead_id}`
- If worktree exists for bead_id, reuse it (same isolated context)
- All subagents working on same bead share same worktree

### State Management

Single source of truth in main repo:
- State file: `.claude/god-ralph/ralph-session.json` (main repo only)
- Worktree gets symlink to main repo state directory
- stop-hook.sh always reads from main repo path

### Scribe Inheritance

Scribe inherits worktree from caller via `worktree_policy: "optional"`:
- When called from ralph-worker in worktree → writes to worktree's CLAUDE.md
- Changes merge together with code changes
- Avoids cross-branch doc drift during parallel execution

## Codebase Findings

### Existing Patterns

**hooks/ensure-worktree.sh:37-51** - Current type-based dispatch:
```bash
# FRAGILE: whitelist approach
AGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // empty')
if [[ "$AGENT_TYPE" =~ ^(god-ralph-orchestrator|bead-farmer|verification-ralph|scribe)$ ]]; then
    exit 0  # Pass through
fi
```

**hooks/ensure-worktree.sh:68-81** - Fragile bead ID extraction:
```bash
# FALSE POSITIVES: "my-feature-branch" could match
BEAD_ID=$(echo "$PROMPT" | grep -oE '(beads|task|bug|feature|fix|epic)-[a-zA-Z0-9]{3,12}' | head -1)
if [ -z "$BEAD_ID" ]; then
    BEAD_ID="ralph-$(date +%s)"  # POOR UX: timestamp fallback
fi
```

**hooks/ensure-worktree.sh:115-150** - Duplicate state creation:
```bash
# Creates in main repo
mkdir -p ".claude/god-ralph"
echo "$SESSION_STATE" > ".claude/god-ralph/ralph-session.json"

# ALSO copies to worktree - NO SYNC MECHANISM
mkdir -p "$WORKTREE_PATH/.claude/god-ralph"
cp ".claude/god-ralph/ralph-session.json" "$WORKTREE_PATH/.claude/god-ralph/"
```

**hooks/stop-hook.sh:52-66** - Hardcoded promise matching:
```bash
# PROBLEM: completion_promise is user-customizable per BEAD_SPEC.md
COMPLETION_PROMISE="BEAD COMPLETE"
if grep -qF "<promise>$COMPLETION_PROMISE</promise>" "$TRANSCRIPT_PATH"; then
```

**agents/orchestrator.md:84-96** - Current dispatch table:
```markdown
| Agent Type | Worktree | Use Case |
|------------|----------|----------|
| ralph-worker | YES | Bead execution |
| bead-farmer | NO | Issue decomposition |
| verification-ralph | OPTIONAL | Post-merge verification |
| scribe | NO | Documentation updates |
```

**agents/ralph-worker.md:276-327** - Current scribe invocation (no worktree awareness):
```markdown
Task(
  subagent_type: "scribe",
  prompt: "Update CLAUDE.md with learning: ..."
)
```

### Key Files to Modify

| File | Change Type | Description |
|------|-------------|-------------|
| hooks/ensure-worktree.sh | Major rewrite | Policy-driven logic, explicit bead_id, symlink state |
| hooks/stop-hook.sh | Modify | Read state from main repo, read promise from state |
| agents/orchestrator.md | Modify | Pass bead_id, worktree_path, worktree_policy in all Task calls |
| agents/ralph-worker.md | Modify | Pass worktree context to scribe, use canonical bead-farmer invocation |
| agents/scribe.md | Modify | Add worktree awareness, inherit caller's context |
| agents/bead-farmer.md | Modify | Add frontmatter with worktree_policy: none |
| agents/verification-ralph.md | Modify | Add frontmatter, use canonical invocations |
| hooks/hooks.json | Modify | Remove global hooks that should be agent-scoped |
| NEW: hooks/doc-only-check.sh | Create | Enforce scribe can only edit .md files |
| reference/BEAD_SPEC.md | Modify | Add canonical bead-farmer invocation template |

## Constraints

### Must Follow
- All Task invocations MUST include explicit `worktree_policy` parameter
- Worktrees MUST be keyed by `bead_id`, never auto-generated timestamps
- State files MUST exist only in main repo (worktree gets symlink)
- Scribe MUST inherit worktree from caller when available
- Hooks MUST be deterministic based on input, not heuristics

### Existing Patterns to Preserve
- Hook JSON response format: `{"updatedInput": {...}}`
- State file structure in `.claude/god-ralph/`
- Git worktree commands and branch naming
- Promise tag format: `<promise>...</promise>`
- YAML frontmatter in agent files

### Technical Requirements
- Bash 4+ for associative arrays in hooks
- jq for JSON parsing (already used)
- git worktree support (already used)
- Symlinks for state file sharing

## Edge Cases

### Worktree Already Exists
- If `.worktrees/ralph-{bead_id}` exists, reuse it
- Check branch matches expected: `ralph/{bead_id}`
- If branch mismatch, error with clear message

### Missing Required Fields
- `worktree_policy: required` but no `bead_id` → error exit 2, clear message
- `worktree_policy: required` but no `worktree_path` → error exit 2
- Allow orchestrator to pass computed worktree_path OR let hook compute from bead_id

### State File Corruption
- If state file unreadable, stop-hook should allow exit (fail open)
- Log warning to stderr for debugging
- Don't block completion on state issues

### Parallel Ralphs Same Bead
- Should not happen (orchestrator assigns 1 Ralph per bead)
- If worktree locked, error with "bead already in progress"

### Scribe Without Worktree Context
- If `worktree_policy: optional` and no worktree_path, write to main repo
- This is correct for orchestrator-level scribe calls

### Promise Format Variations
- Read actual `completion_promise` from state file
- Default to "BEAD COMPLETE" if not in state
- Handle escaped characters in promise text

## Acceptance Criteria (Feature-Level)

### Functional
- [ ] Orchestrator spawns ralph-worker with explicit bead_id, worktree_path, worktree_policy
- [ ] Hook creates worktree ONLY when worktree_policy is "required" or "optional" with bead_id
- [ ] Hook passes through unchanged when worktree_policy is "none"
- [ ] State file exists only in main repo, worktree has symlink
- [ ] Scribe writes to worktree's CLAUDE.md when called from ralph-worker
- [ ] Scribe writes to main repo when called without worktree context
- [ ] All agent files have YAML frontmatter with appropriate policies
- [ ] Bead-farmer invocations follow canonical template across all agents

### Verification
- [ ] Two parallel Ralphs can work without state conflicts
- [ ] `echo '{"worktree_policy":"required","bead_id":"test"}' | ./hooks/ensure-worktree.sh` creates worktree
- [ ] `echo '{"worktree_policy":"none"}' | ./hooks/ensure-worktree.sh` passes through
- [ ] After merge, CLAUDE.md changes from worktree appear in main branch
- [ ] Error messages are clear when required fields missing

### Non-Regression
- [ ] Existing `/god-ralph start` workflow still functions
- [ ] Single-bead execution via `/god-ralph run-bead` still works
- [ ] Stop hook iteration loop still increments and re-injects prompt

## User Requirements

From plan review:
- Phase 1 (Architectural) + Phase 2 (Bug fixes) in scope
- Scribe should inherit worktree from caller (Option A)
- No Windows/cross-platform support needed (Tier 4, out of scope)
- No prompt condensation in this phase (Tier 3, separate work)

## Notes

### Implementation Sequence
These changes are interdependent. Suggested order:
1. ensure-worktree.sh policy logic (enables everything else)
2. orchestrator.md Task invocations (uses new policy)
3. stop-hook.sh state reading (uses symlinked state)
4. ralph-worker.md scribe invocation (passes context)
5. scribe.md worktree awareness (receives context)
6. Agent frontmatter updates (consolidates hook ownership)
7. Canonical invocation template (standardizes patterns)

### Testing Strategy
Manual testing with:
```bash
# Test required policy
echo '{"subagent_type":"ralph-worker","worktree_policy":"required","bead_id":"beads-test","prompt":"test"}' | ./hooks/ensure-worktree.sh

# Test none policy
echo '{"subagent_type":"bead-farmer","worktree_policy":"none","prompt":"test"}' | ./hooks/ensure-worktree.sh

# Test missing bead_id with required
echo '{"subagent_type":"ralph-worker","worktree_policy":"required","prompt":"test"}' | ./hooks/ensure-worktree.sh
# Should exit 2 with error
```

### Future Work (Out of Scope)
- Prompt condensation (~40% reduction across agents)
- Cross-platform Node.js hooks
- Schema integration for ralph_spec (currently in bead comments)
- Better error messages with extracted values
