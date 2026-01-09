---
description: Create a new Claude Code plugin with AI-assisted code generation
---

# Add Plugin Command

You are helping the user create a new Claude Code plugin and add it to a marketplace. This is an AI-powered plugin generator that interviews the user about their requirements, then generates fully functional plugin code.

## Overview

This command will:
1. Help you select a target marketplace
2. Gather plugin specifications through an interactive interview
3. Generate complete, working plugin code
4. Register the plugin in the marketplace

---

## Phase 1: Marketplace Selection

First, identify available marketplaces by reading `~/.claude/plugins/known_marketplaces.json`.

For each marketplace entry, extract:
- Marketplace name (the key)
- Source information (GitHub repo, URL, etc.)
- Install location path

Present options to the user:

> "Which marketplace should I add this plugin to?
>
> 1. [marketplace-name] ([source-repo-or-path])
> 2. [another-marketplace] ([source])
> ...
>
> Enter the number or marketplace name:"

### Validation

After selection, verify:
1. The marketplace has an `installLocation` field
2. The install location directory exists and is writable
3. A `marketplace.json` file exists at `[installLocation]/.claude-plugin/marketplace.json`

If validation fails:

> "Cannot write to marketplace '[name]':
> - [specific issue]
>
> Please ensure the marketplace is properly installed locally.
> You may need to clone the repository or run `/plugin marketplace add` first."

---

## Phase 2: Plugin Metadata

### Plugin Name

Ask: "What should this plugin be called?"

**Validation Rules:**
- Must be kebab-case (lowercase letters, numbers, hyphens only)
- Must start with a letter
- Cannot start or end with hyphen
- Cannot contain consecutive hyphens
- Must be between 2-50 characters

**Check for conflicts:**
Read the marketplace.json and check if any plugin in the `plugins` array has the same name.

If name is invalid:

> "Plugin names must be kebab-case (e.g., 'my-cool-plugin').
> '[input]' is invalid because [specific reason].
>
> Please choose a different name:"

If name conflicts:

> "A plugin named '[name]' already exists in [marketplace-name].
>
> Suggestions:
> - '[name]-v2'
> - '[name]-new'
> - 'my-[name]'
>
> Please choose a different name:"

### Description

Ask: "Describe what this plugin should do (1-2 sentences):"

This becomes the plugin.json description and marketplace entry description.

### Author

Check if the marketplace.json has an `owner` field. If so, offer to use it:

> "Use '[owner-name]' as the author? [y/n]"

If no owner or user declines:

> "Who is the author? (name, optionally email):"

### Optional Metadata

Ask: "Any keywords/tags for discoverability? (comma-separated, or press Enter to skip):"

Default license to MIT unless user specifies otherwise.

---

## Phase 3: Feature Description

Ask:

> "Now describe in detail what features this plugin should have.
>
> What commands should it provide? What should each command do?
> Include any specific behaviors, integrations, or capabilities you need.
>
> Be as detailed as possible - this helps me generate better code:"

Wait for user's detailed description.

### Component Inference

Analyze the description to identify needed components:

**Commands** - Look for:
- Action verbs: "create", "list", "update", "delete", "sync", "check", "run"
- User-facing operations described as discrete actions
- Distinct features that need separate entry points
- Anything described as "a command to..." or "ability to..."

**Skills** - Look for:
- Complex logic that should be reusable across commands
- Operations that multiple commands might share
- Background intelligence/reasoning capabilities
- Anything described as needing "understanding" or "analysis"

**Hooks** - Look for:
- Event-driven automation ("when X happens, do Y")
- Session lifecycle needs ("at startup...", "before closing...")
- Automatic triggers ("automatically...", "whenever...")
- References to: PreToolUse, PostToolUse, SessionStart, SessionEnd, etc.

**MCP Servers** - Look for:
- External API integrations
- Third-party service access (GitHub, Slack, databases, etc.)
- Data fetching from external sources
- References to specific services or APIs

### Present Analysis

> "Based on your description, I'll create:
>
> **Commands:**
> - `/[plugin-name]:[command-1]` - [inferred purpose]
> - `/[plugin-name]:[command-2]` - [inferred purpose]
>
> **Skills:** (if any)
> - `[skill-name]` - [inferred purpose]
>
> **Hooks:** (if any)
> - `[event-type]` - [inferred purpose]
>
> **MCP Servers:** (if any)
> - `[server-name]` - [inferred purpose]
>
> Does this look right? Should I add, remove, or modify anything?"

Allow user to adjust the component list before proceeding.

---

## Phase 4: Command Specifications

For each identified command, gather detailed specifications:

> "Let's define the '[command-name]' command:
>
> 1. What exactly should it do when invoked?
> 2. What arguments or flags should it accept? (e.g., --verbose, --dry-run, filename)
> 3. What output should it produce on success?
> 4. How should it handle errors?"

Gather:
- Detailed behavior description
- Expected arguments (will be available via `$ARGUMENTS`)
- Common flags (--help, --verbose, --dry-run, etc.)
- Success message format
- Error handling approach

---

## Phase 5: Skill Specifications

For each identified skill:

> "Let's define the '[skill-name]' skill:
>
> 1. Should users be able to invoke this directly, or is it internal to the plugin?
> 2. When should this skill activate automatically? (what triggers it?)
> 3. What specific capabilities or knowledge should it have?"

Gather:
- User-invocable: true/false
- Trigger patterns (what context activates it)
- Core capabilities and knowledge domains

---

## Phase 6: Hook Specifications

For each identified hook:

> "Let's define the '[event-type]' hook:
>
> 1. What event should trigger this? (SessionStart, PreToolUse, etc.)
> 2. What action should occur? (run a command, show a prompt, etc.)
> 3. Any conditions for when it should/shouldn't run?"

Available hook events:
- `PreToolUse` / `PostToolUse` / `PostToolUseFailure`
- `PermissionRequest`
- `UserPromptSubmit`
- `Notification`
- `Stop`
- `SubagentStart` / `SubagentStop`
- `SessionStart` / `SessionEnd`
- `PreCompact`

---

## Phase 7: MCP Server Specifications

For each identified MCP server:

> "Let's configure the '[server-name]' MCP server:
>
> 1. Is this a local command (stdio) or remote URL (http/sse)?
> 2. [If stdio] What command starts the server? (e.g., 'npx @org/mcp-server')
> 3. [If http/sse] What is the endpoint URL?
> 4. Are any environment variables needed? (like API keys)"

Gather:
- Type: stdio, http, or sse
- Command or URL
- Required environment variables
- Any additional configuration

---

## Phase 8: Preview & Confirmation

Generate and display the planned structure:

> "Here's what I'll create:
>
> ```
> [marketplace-path]/[plugin-name]/
> ├── .claude-plugin/
> │   └── plugin.json
> ├── commands/
> │   ├── [command-1].md
> │   └── [command-2].md
> ├── skills/                    (if skills)
> │   └── [skill-name]/
> │       └── SKILL.md
> ├── hooks/                     (if hooks)
> │   └── hooks.json
> └── .mcp.json                  (if MCP servers)
> ```
>
> **Plugin Manifest (plugin.json):**
> ```json
> {
>   "name": "[plugin-name]",
>   "description": "[description]",
>   "version": "1.0.0",
>   "author": { "name": "[author]" },
>   "keywords": [...],
>   "license": "MIT"
> }
> ```
>
> **Marketplace Changes:**
> Adding entry to [marketplace-name]/marketplace.json:
> ```json
> {
>   "name": "[plugin-name]",
>   "source": "./[plugin-name]",
>   "description": "[description]"
> }
> ```
>
> Ready to generate? [y/n]"

Wait for confirmation before proceeding.

---

## Phase 9: File Generation

### Create Plugin Directory Structure

```bash
mkdir -p [marketplace-path]/[plugin-name]/.claude-plugin
mkdir -p [marketplace-path]/[plugin-name]/commands
# mkdir -p [marketplace-path]/[plugin-name]/skills/[skill-name] (if skills)
# mkdir -p [marketplace-path]/[plugin-name]/hooks (if hooks)
```

### Generate plugin.json

Create `[plugin-name]/.claude-plugin/plugin.json`:

```json
{
  "name": "[plugin-name]",
  "description": "[user-provided-description]",
  "version": "1.0.0",
  "author": {
    "name": "[author-name]"
  },
  "keywords": ["[keyword1]", "[keyword2]"],
  "license": "MIT"
}
```

### Generate Command Files

For each command, create `commands/[command-name].md`:

```markdown
---
description: [one-line-description]
---

# [Command Name] Command

You are helping the user [purpose of this command].

## Arguments

Parse `$ARGUMENTS` for:
- [arg1]: [description]
- [arg2]: [description]

## Flags

Check for these flags in `$ARGUMENTS`:
- `--help`: Show usage information
- `--verbose`: Enable detailed output
- [other flags as specified]

## Behavior

[Detailed implementation instructions based on user specifications]

### Step 1: [First action]
[Instructions]

### Step 2: [Second action]
[Instructions]

### Step 3: [Third action]
[Instructions]

## Success Output

On successful completion:
> "[Success message format]"

## Error Handling

If [error condition]:
> "[Error message]"
> [Recovery instructions]
```

### Generate Skill Files (if applicable)

For each skill, create `skills/[skill-name]/SKILL.md`:

```markdown
---
name: [skill-name]
description: [skill-description]
user-invocable: [true/false]
---

# [Skill Name]

[Detailed skill instructions and capabilities]

## Trigger Conditions

This skill activates when:
- [trigger-condition-1]
- [trigger-condition-2]

## Capabilities

[Detailed description of what this skill can do]

## Implementation

[Step-by-step instructions for skill behavior]
```

### Generate Hooks File (if applicable)

Create `hooks/hooks.json`:

```json
{
  "[EventType]": [
    {
      "type": "command",
      "command": "[shell-command]"
    }
  ]
}
```

Or for prompt-type hooks:

```json
{
  "[EventType]": [
    {
      "type": "prompt",
      "prompt": "[instruction-for-claude]"
    }
  ]
}
```

### Generate MCP Config (if applicable)

Create `.mcp.json`:

```json
{
  "[server-name]": {
    "type": "[stdio|http|sse]",
    "command": "[command]",
    "args": ["[arg1]", "[arg2]"],
    "env": {
      "[VAR_NAME]": "[value-or-placeholder]"
    }
  }
}
```

Or for HTTP/SSE:

```json
{
  "[server-name]": {
    "type": "[http|sse]",
    "url": "[endpoint-url]"
  }
}
```

### Update marketplace.json

Read the existing `[marketplace-path]/.claude-plugin/marketplace.json`, add the new plugin to the `plugins` array:

```json
{
  "name": "[plugin-name]",
  "source": "./[plugin-name]",
  "description": "[description]"
}
```

Write the updated marketplace.json.

---

## Phase 10: Completion

After all files are generated:

> "Plugin '[plugin-name]' has been created!
>
> **Files created:**
> - [marketplace-path]/[plugin-name]/.claude-plugin/plugin.json
> - [marketplace-path]/[plugin-name]/commands/[command-1].md
> - [marketplace-path]/[plugin-name]/commands/[command-2].md
> - [list all other files]
>
> **Marketplace updated:**
> - [marketplace-path]/.claude-plugin/marketplace.json
>
> ## Next Steps
>
> 1. **Review** the generated code in:
>    `[marketplace-path]/[plugin-name]/`
>
> 2. **Modify** any commands or skills as needed - the generated code
>    is a starting point you can customize.
>
> 3. **Commit and push** changes to the marketplace repository:
>    ```bash
>    cd [marketplace-path]
>    git add .
>    git commit -m 'Add [plugin-name] plugin'
>    git push
>    ```
>
> 4. **Update the marketplace** in Claude Code:
>    ```
>    /plugin marketplace update [marketplace-name]
>    ```
>
> 5. **Install your plugin**:
>    ```
>    /plugin install [plugin-name]@[marketplace-name]
>    ```
>
> Your plugin is ready to use after these steps!"

---

## Error Recovery

### If file creation fails

> "Failed to create [file-path]: [error-message]
>
> Partial files may have been created. Would you like me to:
> 1. Retry the failed operation
> 2. Clean up partial files and start over
> 3. Continue with remaining files (manual fix needed later)"

### If marketplace.json update fails

> "Plugin files were created successfully, but updating marketplace.json failed:
> [error-message]
>
> You can manually add this entry to [marketplace-path]/.claude-plugin/marketplace.json:
> ```json
> {
>   "name": "[plugin-name]",
>   "source": "./[plugin-name]",
>   "description": "[description]"
> }
> ```"
