---
description: Update an existing skill in both Claude Code and Codex
---

# Update Skill Command

You are helping the user update an existing skill in both systems.

## Arguments Parsing

Parse `$ARGUMENTS` for:
- **Skill name**: Which skill to update (required)
- **Changes**: What to modify (description, add files, update instructions, etc.)

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only update Claude Code
- `--codex-only`: Only update Codex
- `--project`: Use project scope

## Flow

### Step 1: Find Skill

**Locate existing skill:**

For Claude (check in order):
1. `.claude/skills/SKILL_NAME/` (project scope)
2. `~/.claude/skills/SKILL_NAME/` (user scope)

For Codex (check in order):
1. `.codex/skills/SKILL_NAME/` (project scope)
2. `~/.codex/skills/SKILL_NAME/` (user scope)

If skill not found:
> "Skill 'NAME' not found. Would you like to create it? Use `/meta-unify:add-skill`"

### Step 2: Show Current State

Display the skill's current structure:
> "Current state of skill 'SKILL_NAME':
>
> **Claude** (~/.claude/skills/SKILL_NAME/):
> ```
> SKILL.md (45 lines)
> references/
>   security-guidelines.md
> ```
>
> **Codex** (~/.codex/skills/SKILL_NAME/):
> ```
> SKILL.md (42 lines)
> references/
>   security-guidelines.md
> ```
>
> What would you like to update?"

### Step 3: Parse Requested Changes

Common update types:
- **Update description**: Modify the YAML frontmatter description
- **Update instructions**: Modify the SKILL.md body content
- **Add reference file**: Create new file in references/
- **Add script**: Create new file in scripts/
- **Add asset**: Create new file in assets/
- **Add Claude-specific features**: Add allowed-tools, model, or context to Claude version only

### Step 4: Apply Updates

**Updating SKILL.md:**
1. Read current content
2. Parse YAML frontmatter and body
3. Apply changes
4. Write back

**Adding reference files:**
1. Create references/ directory if needed
2. Write new file with provided content
3. Do this for BOTH systems (references are portable)

**Adding Claude-specific features:**
- Only modify Claude's SKILL.md
- Warn user: "This feature is Claude-only and won't affect Codex"

### Step 5: Handle Description Length

If updating description:
- Claude max: 1024 characters
- Codex max: 500 characters

If description exceeds Codex limit:
> "Your description is X characters. Claude allows up to 1024, but Codex only allows 500.
>
> For Codex, I'll use this truncated version:
> '[truncated description]...'
>
> Is this acceptable?"

### Step 6: Validate and Write

1. Validate YAML frontmatter syntax
2. Backup original files
3. Write updated files to both systems

### Step 7: Confirm

> "Updated skill 'SKILL_NAME':
>
> **Changes applied:**
> - Updated description
> - Added references/typescript-patterns.md
>
> **Files modified:**
> - Claude: ~/.claude/skills/SKILL_NAME/SKILL.md
> - Claude: ~/.claude/skills/SKILL_NAME/references/typescript-patterns.md
> - Codex: ~/.codex/skills/SKILL_NAME/SKILL.md
> - Codex: ~/.codex/skills/SKILL_NAME/references/typescript-patterns.md
>
> Restart Claude Code and Codex to apply changes."

## Examples

**User input:** "/meta-unify:update-skill code-review Add reference docs for TypeScript patterns"
- Skill: code-review
- Change: Add references/typescript-patterns.md

**User input:** "/meta-unify:update-skill deploy Update the description to mention Kubernetes"
- Skill: deploy
- Change: Modify description in SKILL.md frontmatter

**User input:** "/meta-unify:update-skill security-scan Add allowed-tools restriction for Bash only"
- Skill: security-scan
- Change: Add `allowed-tools: Bash` to Claude SKILL.md only

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
