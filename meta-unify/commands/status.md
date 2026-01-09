---
description: Show configuration state across both Claude Code and Codex systems
---

# Status Command

You are showing the user a comprehensive view of their configuration state across both Claude Code and Codex.

## Arguments Parsing

Parse `$ARGUMENTS` for optional filters:
- `mcp` - Show only MCP servers
- `skills` - Show only skills
- `hooks` - Show only hooks (Claude)
- `rules` - Show only rules/permissions
- `instructions` - Show only instruction files

If no filter, show everything.

## Flags

Check for these flags in `$ARGUMENTS`:
- `--project`: Also include project-scope configs (default: user-scope only)

## Flow

### Step 1: Gather Configuration Data

**MCP Servers:**
- Claude user: Read `~/.claude.json` → `mcpServers`
- Claude project: Read `.mcp.json` → `mcpServers` (if --project)
- Codex: Read `~/.codex/config.toml` → `[mcp_servers.*]`

**Skills:**
- Claude user: List `~/.claude/skills/*/SKILL.md`
- Claude project: List `.claude/skills/*/SKILL.md` (if --project)
- Codex user: List `~/.codex/skills/*/SKILL.md`
- Codex project: List `.codex/skills/*/SKILL.md` (if --project)

**Hooks (Claude only):**
- Claude user: Read `~/.claude/settings.json` → `hooks`
- Claude project: Read `.claude/settings.json` → `hooks` (if --project)

**Rules/Permissions:**
- Claude: Read settings.json → `permissions` (allow/ask/deny)
- Codex: Read `~/.codex/rules/*.rules`

**Instructions:**
- Claude user: Check `~/.claude/CLAUDE.md`
- Claude project: Check `.claude/CLAUDE.md` (if --project)
- Codex user: Check `~/.codex/AGENTS.md`
- Codex project: Check `AGENTS.md` (if --project)

### Step 2: Determine Badges

For each config item, determine where it exists:
- `[Both]` - Exists in both Claude and Codex
- `[Claude]` - Only in Claude Code
- `[Codex]` - Only in Codex

### Step 3: Format Output

Generate a unified list with badges:

```
╔══════════════════════════════════════════════════════════════╗
║                    META-UNIFY STATUS                         ║
╚══════════════════════════════════════════════════════════════╝

📡 MCP SERVERS
──────────────────────────────────────────────────────────────
  [Both]   context7     npx @upstash/context7-mcp
  [Claude] github       https://api.github.com/mcp
  [Codex]  figma        https://mcp.figma.com

🎯 SKILLS
──────────────────────────────────────────────────────────────
  [Both]   code-review  Analyzes PRs for issues
  [Claude] deploy       Deploy to Vercel (uses allowed-tools)
  [Codex]  test-runner  Runs test suites

🪝 HOOKS (Claude only)
──────────────────────────────────────────────────────────────
  PostToolUse(Edit|Write)  →  npm run lint:fix
  SessionStart             →  source ~/.env

🔒 RULES/PERMISSIONS
──────────────────────────────────────────────────────────────
  [Both]   git push    →  prompt/ask
  [Claude] rm -rf      →  deny
  [Codex]  npm publish →  forbidden

📝 INSTRUCTIONS
──────────────────────────────────────────────────────────────
  [Both]   User-scope instructions configured
  [Claude] ~/.claude/CLAUDE.md (245 lines)
  [Codex]  ~/.codex/AGENTS.md (198 lines)

──────────────────────────────────────────────────────────────
Summary: 3 MCP servers | 3 skills | 2 hooks | 3 rules
Claude: ~/.claude/ | Codex: ~/.codex/
```

### Step 4: Handle Missing Configs

If a system has no configs:
```
📡 MCP SERVERS
──────────────────────────────────────────────────────────────
  [Claude] context7     npx @upstash/context7-mcp

  ⚠️  No MCP servers configured in Codex
      Run /meta-unify:add-mcp to add servers
```

### Step 5: Show Warnings

Highlight potential issues:
- MCP server in one system but not the other
- Skills with different descriptions between systems
- Missing instruction files
- Syntax errors in config files (if detected)

```
⚠️  WARNINGS
──────────────────────────────────────────────────────────────
  • MCP 'github' only in Claude - run /meta-unify:sync to align
  • Skill 'deploy' uses Claude-only features (allowed-tools)
  • Codex AGENTS.md not found - run /meta-unify:instructions
```

## Filtered Output Examples

**`/meta-unify:status mcp`:**
Only shows MCP servers section

**`/meta-unify:status skills --project`:**
Shows skills from both user and project scopes

## Reference

For file locations and formats, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
