---
description: Add an MCP server to both Claude Code and Codex configurations
---

# Add MCP Server Command

You are helping the user add an MCP server to their Claude Code and Codex configurations.

## Arguments Parsing

Parse `$ARGUMENTS` for MCP server details:
- **Server name**: Look for a clear identifier (e.g., "context7", "github", "figma")
- **Transport type**:
  - STDIO if mentions "npx", "node", "python", a command, or local execution
  - HTTP if mentions "https://", a URL, or remote/cloud
- **Command/URL**: The actual command (for STDIO) or URL (for HTTP)
- **Environment variables**: Look for "env", "token", "key", or KEY=VALUE patterns

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only configure Claude Code
- `--codex-only`: Only configure Codex
- `--project`: Use project scope instead of user scope (default: user scope)

## Flow

### Step 1: Extract Information

If the user provided sufficient context (server name + command/URL), proceed to Step 2.

If missing required information, ask conversationally:
> "I'll help you add an MCP server. I need a few details:
> - What should this server be called? (e.g., 'context7', 'github')
> - Is this a local server (runs a command) or remote server (connects to URL)?
> - What command should start it / What URL should it connect to?
> - Any environment variables needed (like API tokens)?"

### Step 2: Validate

Before configuring:
1. For STDIO servers: Check if the command exists (e.g., `which npx`)
2. For HTTP servers: Validate URL format
3. Validate JSON syntax for Claude config
4. Validate TOML syntax for Codex config

### Step 3: Determine Target Files

**User Scope (default):**
- Claude: `~/.claude.json` (add to `mcpServers` object)
- Codex: `~/.codex/config.toml` (add `[mcp_servers.NAME]` section)

**Project Scope (--project flag):**
- Claude: `.mcp.json` in current directory
- Codex: Project scope not supported for Codex MCP - warn user

### Step 4: Generate Configurations

**For Claude (JSON format):**
```json
{
  "mcpServers": {
    "SERVER_NAME": {
      "command": "command here",
      "args": ["arg1", "arg2"],
      "env": {
        "KEY": "value"
      }
    }
  }
}
```

For HTTP servers, use:
```json
{
  "mcpServers": {
    "SERVER_NAME": {
      "type": "http",
      "url": "https://...",
      "headers": {
        "Authorization": "Bearer ${TOKEN_ENV_VAR}"
      }
    }
  }
}
```

**For Codex (TOML format):**
```toml
[mcp_servers.SERVER_NAME]
command = "command here"
args = ["arg1", "arg2"]

[mcp_servers.SERVER_NAME.env]
KEY = "value"
```

For HTTP servers:
```toml
[mcp_servers.SERVER_NAME]
url = "https://..."
bearer_token_env_var = "TOKEN_ENV_VAR"
```

### Step 5: Apply Changes

1. Read existing config files (create if they don't exist)
2. Merge new server config (don't overwrite existing servers)
3. Write updated configs
4. If one system fails: Ask user "Claude config succeeded but Codex failed. Keep Claude changes? [y/n]"

### Step 6: Confirm

Report success with details:
> "Added MCP server 'SERVER_NAME' to:
> - Claude: ~/.claude.json
> - Codex: ~/.codex/config.toml
>
> Restart Claude Code and Codex to load the new server."

## Examples

**User input:** "Add context7 using npx @upstash/context7-mcp"
- Name: context7
- Transport: STDIO
- Command: npx
- Args: ["@upstash/context7-mcp"]

**User input:** "Add the Figma MCP at https://mcp.figma.com with FIGMA_TOKEN"
- Name: figma
- Transport: HTTP
- URL: https://mcp.figma.com
- Auth: bearer_token_env_var = "FIGMA_TOKEN"

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
