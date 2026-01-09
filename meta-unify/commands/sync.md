---
description: Align configurations between Claude Code and Codex with diff review
---

# Sync Command

You are helping the user synchronize configurations between Claude Code and Codex, showing differences and offering to align them.

## Arguments Parsing

Parse `$ARGUMENTS` for optional filters:
- `mcp` - Sync only MCP servers
- `skills` - Sync only skills
- `rules` - Sync only rules/permissions
- `instructions` - Sync only instruction files

If no filter, analyze everything.

## Flags

Check for these flags in `$ARGUMENTS`:
- `--dry-run`: Show what would be synced without making changes
- `--auto`: Automatically sync all differences (don't ask for each)

## Flow

### Step 1: Gather Configuration Data

Read configurations from both systems (same as status command):
- MCP servers from Claude and Codex
- Skills from both systems
- Rules/permissions from both systems
- Instructions from both systems

### Step 2: Identify Differences

For each config type, categorize items:

**Claude-only items:** Exist in Claude but not Codex
**Codex-only items:** Exist in Codex but not Claude
**Both (matching):** Same config in both systems
**Both (different):** Same name but different content

### Step 3: Show Diff Report

```
╔══════════════════════════════════════════════════════════════╗
║                    SYNC ANALYSIS                             ║
╚══════════════════════════════════════════════════════════════╝

📡 MCP SERVERS
──────────────────────────────────────────────────────────────
  ✓ context7       In both (matching)
  → github         Claude only - can sync to Codex
  ← figma          Codex only - can sync to Claude

🎯 SKILLS
──────────────────────────────────────────────────────────────
  ✓ code-review    In both (matching)
  ⚡ deploy         In both but DIFFERENT content
      Claude: "Deploy applications to Vercel"
      Codex:  "Deploy apps to production servers"
  → test-helper    Claude only - can sync to Codex

🔒 RULES
──────────────────────────────────────────────────────────────
  ✓ git push       In both (ask/prompt)
  → rm -rf         Claude only (deny) - can sync to Codex

📝 INSTRUCTIONS
──────────────────────────────────────────────────────────────
  ⚡ Different content
      Claude: 245 lines
      Codex:  198 lines
      (Use /meta-unify:instructions to manage)

──────────────────────────────────────────────────────────────
Legend: ✓ synced | → Claude→Codex | ← Codex→Claude | ⚡ conflict
```

### Step 4: Offer Sync Options

For each difference, ask user what to do:

**Claude-only item:**
> "MCP server 'github' exists in Claude but not Codex.
> Sync to Codex? [y/n/skip]"

**Codex-only item:**
> "MCP server 'figma' exists in Codex but not Claude.
> Sync to Claude? [y/n/skip]"

**Different content:**
> "Skill 'deploy' has different descriptions:
> - Claude: 'Deploy applications to Vercel'
> - Codex: 'Deploy apps to production servers'
>
> Which version to use?
> [c] Use Claude version for both
> [x] Use Codex version for both
> [s] Skip (keep different)
> [m] Merge (combine both descriptions)"

### Step 5: Apply Syncs

For each approved sync:

**Syncing MCP to Codex:**
1. Read Claude's JSON config
2. Translate to TOML format
3. Add to Codex config.toml
4. Validate syntax

**Syncing MCP to Claude:**
1. Read Codex's TOML config
2. Translate to JSON format
3. Add to Claude's .mcp.json or ~/.claude.json
4. Validate syntax

**Syncing Skills:**
1. Copy SKILL.md (adjust frontmatter for each system)
2. Copy references/ and other supporting files
3. Handle Claude-specific fields (omit from Codex)

**Syncing Rules:**
1. Translate between permissions JSON and Starlark syntax
2. Map decision types (ask↔prompt, deny↔forbidden)

### Step 6: Handle Non-Syncable Items

Some items can't be synced:
- Hooks (Claude-only feature)
- Claude-specific skill fields (allowed-tools, context, model)

> "Note: The following cannot be synced:
> - 2 hooks (Claude-only feature - Codex uses rules instead)
> - Skill 'deploy' uses Claude-only 'allowed-tools' feature"

### Step 7: Confirm Results

```
╔══════════════════════════════════════════════════════════════╗
║                    SYNC COMPLETE                             ║
╚══════════════════════════════════════════════════════════════╝

✓ Synced MCP 'github' to Codex
✓ Synced MCP 'figma' to Claude
✓ Synced skill 'test-helper' to Codex
✓ Synced rule 'rm -rf' to Codex
⊘ Skipped skill 'deploy' (kept different)

Files modified:
- ~/.claude.json (added figma)
- ~/.codex/config.toml (added github)
- ~/.codex/skills/test-helper/SKILL.md (created)
- ~/.codex/rules/meta-unify.rules (added rule)

Restart both systems to apply changes.
```

## --dry-run Mode

If `--dry-run` flag is present:
- Show the diff report
- Show what WOULD be synced
- Don't make any changes
- End with: "Run without --dry-run to apply these changes"

## --auto Mode

If `--auto` flag is present:
- Automatically sync all Claude-only items to Codex
- Automatically sync all Codex-only items to Claude
- For conflicts, prefer Claude version (or ask)
- Show summary of all changes made

## Reference

For format translation details, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
