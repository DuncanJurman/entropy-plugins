---
description: Update an existing MCP server configuration in both Claude Code and Codex
---

# Update MCP Server Command

You are helping the user update an existing MCP server configuration in both systems.

## Arguments Parsing

Parse `$ARGUMENTS` for:
- **Server name**: Which MCP server to update (required)
- **Changes**: What to modify (command, args, env vars, etc.)

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only update Claude Code
- `--codex-only`: Only update Codex
- `--project`: Use project scope for Claude

## Flow

### Step 1: Find Server Configuration

**Locate existing config:**

For Claude (check in order):
1. `.mcp.json` (project scope)
2. `~/.claude.json` (user scope)

For Codex:
1. `~/.codex/config.toml` (user scope only)

If server not found in a system:
> "Server 'NAME' not found in [Claude/Codex]. Would you like to add it instead? Use `/meta-unify:add-mcp`"

### Step 2: Show Current Configuration

Display the current config to the user:
> "Current configuration for 'SERVER_NAME':
>
> **Claude** (~/.claude.json):
> ```json
> {
>   "command": "npx",
>   "args": ["@package/server"],
>   "env": { "TOKEN": "..." }
> }
> ```
>
> **Codex** (~/.codex/config.toml):
> ```toml
> [mcp_servers.SERVER_NAME]
> command = "npx"
> args = ["@package/server"]
> ```
>
> What would you like to change?"

### Step 3: Parse Requested Changes

If user provided changes in `$ARGUMENTS`, proceed. Otherwise, ask:
> "What would you like to update?
> - Command or args?
> - Add/remove environment variables?
> - Change the URL (for HTTP servers)?
> - Something else?"

### Step 4: Apply Updates

Common update scenarios:

**Add environment variable:**
- Claude: Add to `"env": { "NEW_KEY": "value" }`
- Codex: Add to `[mcp_servers.NAME.env]` section

**Change command/args:**
- Claude: Update `"command"` and `"args"` fields
- Codex: Update `command` and `args` in TOML

**Change URL (HTTP servers):**
- Claude: Update `"url"` field
- Codex: Update `url` field

### Step 5: Validate and Write

1. Validate JSON syntax (Claude)
2. Validate TOML syntax (Codex)
3. Backup original files
4. Write updated configurations

### Step 6: Handle Errors

If update fails for one system:
> "Claude update successful, but Codex update failed: [ERROR]
>
> Keep the Claude changes? [y/n]
>
> You can fix the Codex config manually at ~/.codex/config.toml"

### Step 7: Confirm

> "Updated MCP server 'SERVER_NAME':
>
> **Changes applied:**
> - Added environment variable: API_KEY
> - Updated args: added '--verbose' flag
>
> **Files modified:**
> - Claude: ~/.claude.json
> - Codex: ~/.codex/config.toml
>
> Restart Claude Code and Codex to apply changes."

## Examples

**User input:** "/meta-unify:update-mcp context7 Add UPSTASH_TOKEN env variable"
- Server: context7
- Change: Add env var UPSTASH_TOKEN

**User input:** "/meta-unify:update-mcp github Change the URL to https://new-api.github.com/mcp"
- Server: github
- Change: Update URL

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
