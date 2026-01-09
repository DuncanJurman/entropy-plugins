---
description: Add command permission rules to both Claude Code and Codex
---

# Add Rule Command

You are helping the user add command permission rules to both Claude Code and Codex.

**How rules work:**
- **Claude Code**: Uses `permissions` in settings.json with `allow`, `ask`, `deny` arrays
- **Codex**: Uses Starlark rules in `~/.codex/rules/*.rules` with `prefix_rule()` function

Both systems control which shell commands can run and whether to prompt for confirmation.

## Arguments Parsing

Parse `$ARGUMENTS` for rule details:
- **Command pattern**: Which command(s) should this rule match?
- **Decision**: allow, prompt/ask, or deny/forbidden?
- **Reason/justification**: Why is this rule needed?

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only configure Claude Code
- `--codex-only`: Only configure Codex
- `--project`: Use project scope for Claude (Codex rules are always user-scope)

## Decision Mapping

| User Intent | Claude (permissions) | Codex (Starlark) |
|-------------|---------------------|------------------|
| "allow", "permit", "always run" | `allow` array | `decision = "allow"` |
| "ask", "confirm", "prompt" | `ask` array | `decision = "prompt"` |
| "deny", "block", "forbid", "never" | `deny` array | `decision = "forbidden"` |

## Flow

### Step 1: Gather Rule Intent

If the user provided sufficient context, proceed to Step 2.

If missing required information, ask conversationally:
> "I'll help you add a command permission rule. I need to know:
> - **What command** should this rule match? (e.g., 'git push', 'rm -rf', 'npm publish')
> - **What should happen?** Allow it, ask for confirmation, or block it?
> - **Why?** (optional but helps document the rule)"

### Step 2: Generate Claude Permission

**Target file:**
- User scope: `~/.claude/settings.json`
- Project scope: `.claude/settings.json`

**Format:**
```json
{
  "permissions": {
    "allow": ["Bash(npm test:*)"],
    "ask": ["Bash(git push:*)"],
    "deny": ["Bash(rm -rf:*)"]
  }
}
```

**Pattern syntax:**
- `Bash(command:*)` - Match command with any arguments
- `Bash(git push:*)` - Match "git push" with any args
- `Bash(npm run:*)` - Match "npm run" with any args
- `Bash(rm -rf:*)` - Match dangerous rm commands

### Step 3: Generate Codex Starlark Rule

**Target file:** `~/.codex/rules/meta-unify.rules`

**Format:**
```python
# Rule: DESCRIPTION
prefix_rule(
    pattern = ["command", "subcommand"],
    decision = "prompt",
    justification = "REASON_HERE",
)
```

**Pattern syntax:**
- Pattern is a list of command elements: `["git", "push"]` matches `git push`
- Can use unions for alternatives: `["git", ["push", "force-push"]]`
- More specific patterns take precedence

**Decision values:**
- `"allow"` - Run without prompting
- `"prompt"` - Ask before each invocation
- `"forbidden"` - Block without prompting

### Step 4: Apply Changes

**For Claude:**
1. Read existing settings.json
2. Merge into appropriate permissions array (allow/ask/deny)
3. Validate JSON syntax
4. Write updated config

**For Codex:**
1. Check if `~/.codex/rules/` exists, create if not
2. Read or create `meta-unify.rules`
3. Append new rule (avoid duplicates)
4. Validate Starlark syntax
5. Write updated file

### Step 5: Handle Partial Failure

If one system fails:
> "Claude rule added successfully, but Codex rule failed: [ERROR]
> Keep Claude changes? [y/n]"

### Step 6: Confirm

Report success:
> "Added permission rule for 'git push':
>
> **Claude Code:** Added to `ask` array in ~/.claude/settings.json
> ```json
> "ask": ["Bash(git push:*)"]
> ```
>
> **Codex:** Added to ~/.codex/rules/meta-unify.rules
> ```python
> prefix_rule(
>     pattern = ["git", "push"],
>     decision = "prompt",
>     justification = "Confirm before pushing to remote"
> )
> ```
>
> Both systems will now ask for confirmation before running `git push`."

## Examples

**User input:** "Require confirmation before git push"
- Command: git push
- Decision: prompt/ask
- Claude: `"ask": ["Bash(git push:*)"]`
- Codex: `prefix_rule(pattern=["git", "push"], decision="prompt")`

**User input:** "Block all rm -rf commands"
- Command: rm -rf
- Decision: deny/forbidden
- Claude: `"deny": ["Bash(rm -rf:*)"]`
- Codex: `prefix_rule(pattern=["rm", "-rf"], decision="forbidden")`

**User input:** "Always allow npm test"
- Command: npm test
- Decision: allow
- Claude: `"allow": ["Bash(npm test:*)"]`
- Codex: `prefix_rule(pattern=["npm", "test"], decision="allow")`

## Rule Precedence

- **Claude**: deny > ask > allow (most restrictive wins)
- **Codex**: forbidden > prompt > allow (most restrictive wins)

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md (permissions section)
- references/codex-formats.md (rules section)
