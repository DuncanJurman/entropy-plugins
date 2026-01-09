---
description: Add an event-based hook to Claude Code configuration (Claude only - Codex uses rules instead)
---

# Add Hook Command (Claude Only)

You are helping the user add an event-based hook to Claude Code.

**Note:** This command only configures Claude Code. Codex does not have hooks - it uses rules for command-level control instead. If the user wants command-level permissions, suggest `/meta-unify:add-rule` instead.

## Arguments Parsing

Parse `$ARGUMENTS` for hook details:
- **Event type**: When should this hook trigger?
- **Matcher**: Which tools should trigger it? (optional)
- **Command**: What command should run?
- **Purpose**: What is this hook for?

## Flags

Check for these flags in `$ARGUMENTS`:
- `--project`: Use project scope instead of user scope (default: user scope)

## Available Hook Events

| Event | Description | Common Use Cases |
|-------|-------------|------------------|
| `PreToolUse` | Before any tool executes | Block dangerous operations, validate inputs |
| `PostToolUse` | After tool succeeds | Run linters, formatters, tests |
| `PostToolUseFailure` | After tool fails | Log errors, notify |
| `UserPromptSubmit` | Before processing user input | Validate prompts, add context |
| `Stop` | When main agent finishes | Cleanup, notifications |
| `SubagentStop` | When subagent finishes | Log subagent results |
| `SessionStart` | Session begins | Initialize environment |
| `SessionEnd` | Session ends | Cleanup |
| `PreCompact` | Before conversation compaction | Save important context |
| `Notification` | When notifications sent | Custom notification handling |
| `PermissionRequest` | Permission dialog shown | Auto-approve known safe operations |

## Flow

### Step 1: Gather Hook Intent

If the user provided sufficient context, proceed to Step 2.

If missing required information, ask conversationally:
> "I'll help you add a hook to Claude Code. I need to know:
> - **When** should this trigger? (e.g., after file edits, before bash commands, when session starts)
> - **What** should happen? (the command to run)
> - **Which tools** should trigger it? (optional - e.g., only Edit and Write, or all tools)"

### Step 2: Map to Event Type

Based on user description, determine the event:
- "after edit", "after write", "after file change" → `PostToolUse`
- "before running", "block dangerous" → `PreToolUse`
- "when fails", "on error" → `PostToolUseFailure`
- "at start", "on startup" → `SessionStart`
- "when done", "on completion" → `Stop`

### Step 3: Determine Matcher

Matcher patterns for filtering which tools trigger the hook:
- `*` or omit → All tools
- `Write` → Only Write tool
- `Edit|Write` → Edit OR Write tools
- `Bash` → Only Bash tool
- `Notebook.*` → Any Notebook tools (regex)

Common tool names: `Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `Task`

### Step 4: Determine Target File

**User Scope (default):**
- `~/.claude/settings.json`

**Project Scope (--project flag):**
- `.claude/settings.json`

### Step 5: Generate Hook Configuration

```json
{
  "hooks": {
    "EVENT_NAME": [
      {
        "matcher": "TOOL_PATTERN",
        "hooks": [
          {
            "type": "command",
            "command": "COMMAND_HERE",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Hook types:**
- `command` - Execute a shell command (most common)
- `prompt` - LLM-based evaluation (for Stop/SubagentStop)
- `agent` - Complex agentic verification

### Step 6: Apply Changes

1. Read existing settings.json (create if doesn't exist)
2. Merge new hook (preserve existing hooks, add to array if same event)
3. Validate JSON syntax
4. Write updated config

### Step 7: Confirm

Report success:
> "Added hook to Claude Code:
> - Event: PostToolUse
> - Matcher: Edit|Write
> - Command: npm run lint:fix
> - Location: ~/.claude/settings.json
>
> **Note:** Codex doesn't support hooks. For command-level permissions in Codex, use `/meta-unify:add-rule`.
>
> Restart Claude Code to activate the hook."

## Examples

**User input:** "Run eslint after every file edit"
- Event: `PostToolUse`
- Matcher: `Edit|Write`
- Command: `eslint --fix $FILE` (or `npm run lint`)

**User input:** "Block any rm -rf commands"
- Event: `PreToolUse`
- Matcher: `Bash`
- Command: Script that checks for dangerous patterns and exits with code 2 to block

**User input:** "Run tests when I'm done"
- Event: `Stop`
- Matcher: (none needed)
- Command: `npm test`

## Environment Variables Available to Hooks

- `$FILE` - The file being operated on (for file-related tools)
- `$TOOL_NAME` - Name of the tool being executed
- `$SESSION_ID` - Current session identifier

## Reference

For complete hook specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md (hooks section)
