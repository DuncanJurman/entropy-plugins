---
description: Diagnose configuration issues across both Claude Code and Codex
---

# Doctor Command

You are diagnosing configuration issues across both Claude Code and Codex systems.

## Arguments Parsing

Parse `$ARGUMENTS` for optional focus areas:
- `mcp` - Check only MCP configurations
- `skills` - Check only skill configurations
- `hooks` - Check only hooks (Claude)
- `rules` - Check only rules (both systems)
- `syntax` - Only run syntax validation

If no filter, run all checks.

## Flags

Check for these flags in `$ARGUMENTS`:
- `--fix`: Attempt to automatically fix issues where possible
- `--verbose`: Show detailed output for each check

## Flow

### Step 1: Run Diagnostic Checks

Execute all applicable checks and collect results.

### Step 2: Display Results

```
╔══════════════════════════════════════════════════════════════╗
║                    DOCTOR DIAGNOSTICS                        ║
╚══════════════════════════════════════════════════════════════╝

🔍 SYNTAX VALIDATION
──────────────────────────────────────────────────────────────
  ✓ ~/.claude.json                    Valid JSON
  ✓ ~/.claude/settings.json           Valid JSON
  ✓ .mcp.json                         Valid JSON
  ✗ ~/.codex/config.toml              INVALID TOML
      Line 15: Expected '=' after key name
  ✓ ~/.codex/rules/meta-unify.rules   Valid Starlark

📡 MCP SERVERS
──────────────────────────────────────────────────────────────
  ✓ context7    Command 'npx' exists in PATH
  ✗ custom-srv  Command 'my-server' NOT FOUND
      Suggestion: Install the server or update the command path
  ✓ figma       URL https://mcp.figma.com is valid format

🎯 SKILLS
──────────────────────────────────────────────────────────────
  ✓ code-review     Valid SKILL.md in both systems
  ⚠️ deploy         Missing in Codex (Claude-only)
  ✗ test-runner     Invalid YAML frontmatter
      Line 3: Missing required field 'description'
  ⚠️ security-scan  References non-existent file
      references/owasp-guide.md not found

🪝 HOOKS (Claude only)
──────────────────────────────────────────────────────────────
  ✓ PostToolUse     Valid configuration
  ⚠️ SessionStart   Script not executable
      Run: chmod +x ~/.claude/scripts/init.sh

🔒 RULES/PERMISSIONS
──────────────────────────────────────────────────────────────
  ✓ Claude permissions    Valid syntax
  ✗ Codex rules           Duplicate rule detected
      'git push' defined twice in meta-unify.rules

📝 INSTRUCTIONS
──────────────────────────────────────────────────────────────
  ✓ ~/.claude/CLAUDE.md    Exists (245 lines)
  ⚠️ ~/.codex/AGENTS.md     Not found
      Run /meta-unify:instructions to create

──────────────────────────────────────────────────────────────
SUMMARY: 3 errors | 4 warnings | 8 passed

Run with --fix to attempt automatic repairs.
```

## Diagnostic Checks

### Syntax Validation

**JSON files (Claude):**
- `~/.claude.json`
- `~/.claude/settings.json`
- `.claude/settings.json`
- `.mcp.json`

**TOML files (Codex):**
- `~/.codex/config.toml`

**Starlark files (Codex):**
- `~/.codex/rules/*.rules`

**YAML frontmatter (Skills):**
- All `SKILL.md` files

### MCP Server Checks

1. **Command existence** (STDIO servers):
   - Run `which COMMAND` to verify command exists
   - Check PATH accessibility

2. **URL format** (HTTP servers):
   - Validate URL syntax
   - Check for HTTPS (warn if HTTP)

3. **Environment variables**:
   - Check if referenced env vars are set
   - Warn about missing tokens

### Skill Checks

1. **Required fields**:
   - `name` field present and valid
   - `description` field present and within limits

2. **File references**:
   - All referenced files in references/ exist
   - All scripts in scripts/ are executable

3. **Cross-system consistency**:
   - Warn if skill exists in only one system
   - Check for description length issues (Codex 500 char limit)

### Hook Checks (Claude)

1. **Script executability**:
   - All referenced scripts have execute permission

2. **Event names**:
   - Valid event names used

3. **Matcher syntax**:
   - Valid regex patterns

### Permission/Rule Checks

1. **Syntax validation**:
   - Claude permissions array format
   - Codex Starlark prefix_rule() format

2. **Duplicate detection**:
   - Same command pattern defined multiple times

3. **Conflict detection**:
   - Conflicting rules (allow and deny same command)

## --fix Mode

When `--fix` is specified, attempt to repair:

**Fixable issues:**
- Make scripts executable: `chmod +x SCRIPT`
- Remove duplicate rules (keep first)
- Create missing directories
- Initialize missing config files with defaults

**Not fixable (require manual intervention):**
- Invalid JSON/TOML/Starlark syntax
- Missing commands (need to install)
- Missing environment variables
- Content conflicts between systems

```
──────────────────────────────────────────────────────────────
AUTO-FIX RESULTS
──────────────────────────────────────────────────────────────
  ✓ Fixed: Made ~/.claude/scripts/init.sh executable
  ✓ Fixed: Created ~/.codex/rules/ directory
  ✗ Cannot fix: Invalid TOML syntax (manual edit required)
  ✗ Cannot fix: Command 'my-server' not found (install needed)
```

## Exit Summary

End with actionable next steps:

```
──────────────────────────────────────────────────────────────
NEXT STEPS
──────────────────────────────────────────────────────────────
1. Fix TOML syntax error in ~/.codex/config.toml (line 15)
2. Install missing command 'my-server' or update MCP config
3. Add 'description' field to test-runner SKILL.md
4. Run /meta-unify:instructions to create AGENTS.md

Run /meta-unify:doctor --verbose for detailed diagnostics.
```

## Reference

For expected formats and schemas, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
