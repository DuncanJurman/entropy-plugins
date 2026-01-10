# entropy-marketplace

A Claude Code plugin marketplace by Duncan Jurman.

## Installation

### 1. Add the marketplace

```bash
/plugin marketplace add duncanjurman/entropy-plugins
```

### 2. Install plugins

```bash
/plugin install meta-unify@entropy-marketplace
```

### 3. Verify installation

```bash
/meta-unify:status
```

---

## Updating Plugins

To get the latest version of plugins:

```bash
/plugin marketplace update entropy-marketplace
/plugin update meta-unify@entropy-marketplace
```

---

## Available Plugins

### meta-unify

**Unified configuration management for Claude Code and Codex.**

Manage MCP servers, skills, hooks, rules, and instructions across both Claude Code and Codex from a single interface. Automatically translates between formats (JSON, TOML, Starlark) and keeps configurations synchronized.

#### Commands

| Command | Description |
|---------|-------------|
| `/meta-unify:add-mcp` | Add MCP servers to both Claude Code and Codex |
| `/meta-unify:add-skill` | Create skills in both systems |
| `/meta-unify:add-hook` | Add event-based hooks (Claude Code only) |
| `/meta-unify:add-rule` | Add permission rules to both systems |
| `/meta-unify:update-mcp` | Modify existing MCP server configurations |
| `/meta-unify:update-skill` | Modify existing skills |
| `/meta-unify:sync` | Synchronize configurations between systems |
| `/meta-unify:status` | Display configuration state across both systems |
| `/meta-unify:doctor` | Diagnose and fix configuration issues |
| `/meta-unify:instructions` | Manage CLAUDE.md and AGENTS.md files |

#### Features

- **Dual-system management**: Simultaneously manage Claude Code and Codex configurations
- **Format translation**: Automatically converts between JSON, TOML, and Starlark formats
- **Sync detection**: Identifies configuration differences and conflicts between systems
- **Validation**: Built-in syntax validation for all configuration formats
- **Partial failure handling**: Gracefully handles when one system fails while the other succeeds

#### Configuration Types Supported

| Type | Claude Code | Codex |
|------|-------------|-------|
| MCP Servers | `~/.claude.json`, `.mcp.json` | `~/.codex/config.toml` |
| Skills | `~/.claude/skills/` | `~/.codex/skills/` |
| Hooks | `~/.claude/settings.json` | N/A (Claude only) |
| Rules | `permissions` in settings.json | `~/.codex/rules/*.rules` |
| Instructions | `CLAUDE.md` | `AGENTS.md` |

---

### god-ralph

**Autonomous development orchestrator combining ephemeral Ralph workers with Beads task tracking.**

Automates software development by breaking work into granular beads, spawning ephemeral "Ralph" workers to complete each task, running parallel execution on independent work, and automatically verifying merged results.

#### How It Works

1. **Discovery** - Find ready beads via `bd ready`
2. **Spawn** - Create git worktrees, launch parallel Ralph workers
3. **Execute** - Each Ralph works on exactly ONE bead until completion
4. **Merge** - Auto-merge completed branches back to main
5. **Verify** - Run acceptance criteria, create fix-beads if needed

#### Commands

| Command | Description |
|---------|-------------|
| `/god-ralph start` | Start orchestrator (dry-run first) |
| `/god-ralph plan` | Interactive bead creation wizard |
| `/god-ralph status` | Show current progress |
| `/god-ralph stop` | Gracefully stop execution |
| `/god-ralph <id>` | Run Ralph on a specific bead |

#### Requirements

- Beads CLI (`bd`) installed
- Git repository initialized

---

## License

MIT License - see individual plugin directories for details.

---

## Author

Duncan Jurman
