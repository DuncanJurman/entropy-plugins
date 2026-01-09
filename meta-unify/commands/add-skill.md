---
description: Create a skill in both Claude Code and Codex with appropriate format and structure
---

# Add Skill Command

You are helping the user create a new skill for both Claude Code and Codex.

## Arguments Parsing

Parse `$ARGUMENTS` for skill details:
- **Skill name**: Look for a clear identifier (lowercase, hyphens allowed)
- **Description**: What the skill does and when to use it
- **Purpose/behavior**: Key functionality to implement

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only create for Claude Code
- `--codex-only`: Only create for Codex
- `--project`: Use project scope instead of user scope (default: user scope)

## Flow

### Step 1: Gather Skill Intent

If the user provided sufficient context, proceed to Step 2.

If missing required information, ask conversationally:
> "I'll help you create a skill. Tell me:
> - What should this skill be called? (lowercase, use hyphens)
> - What does this skill do? When should it be used?
> - What specific behavior or instructions should it follow?"

### Step 2: Analyze and Recommend Structure

Based on the skill description, recommend appropriate structure:

**Detect keywords and suggest directories:**
- "guidelines", "standards", "reference", "documentation", "API", "patterns" → Suggest `references/` directory
- "deploy", "build", "run", "validate", "execute", "script", "automate" → Suggest `scripts/` directory
- "template", "scaffold", "generate", "boilerplate", "config file" → Suggest `assets/` directory

**Present recommendation:**
> "Based on your description, I recommend this structure:
> - `SKILL.md` - Core instructions for [skill purpose]
> - `references/` - [reason if applicable]
>
> This skill doesn't appear to need [scripts/assets]. Does this structure look right?"

Wait for user confirmation before proceeding.

### Step 3: Determine Target Locations

**User Scope (default):**
- Claude: `~/.claude/skills/SKILL_NAME/`
- Codex: `~/.codex/skills/SKILL_NAME/`

**Project Scope (--project flag):**
- Claude: `.claude/skills/SKILL_NAME/`
- Codex: `.codex/skills/SKILL_NAME/`

### Step 4: Generate SKILL.md Files

**For Claude Code:**

```yaml
---
name: SKILL_NAME
description: DESCRIPTION (max 1024 chars) - What it does and when to use it
user-invocable: true
---

[Body instructions go here]

[Keep under 500 lines - use references/ for supplementary documentation]
```

Optional Claude-specific fields (include if relevant):
- `allowed-tools: Tool1, Tool2` - Restrict which tools the skill can use
- `model: claude-sonnet-4` - Override the model
- `context: fork` - Run in a forked sub-agent

**For Codex:**

```yaml
---
name: SKILL_NAME
description: DESCRIPTION (max 500 chars) - What it does and when to use it
metadata:
  short-description: Brief user-facing description
---

[Body instructions go here]

[Keep small and modular - use references/ for documentation]
```

**Important differences:**
- Claude description max: 1024 chars; Codex: 500 chars (truncate with warning if needed)
- Claude-specific fields (`allowed-tools`, `context`, `model`) are NOT included in Codex version
- Body content can be largely the same

### Step 5: Create Directory Structure

Create only the directories that were confirmed:

```bash
# Always create
mkdir -p SKILL_PATH/

# Only if confirmed
mkdir -p SKILL_PATH/references/
mkdir -p SKILL_PATH/scripts/
mkdir -p SKILL_PATH/assets/
```

### Step 6: Populate Content

1. Write SKILL.md with generated content
2. If `references/` created, add a starter reference file with relevant documentation
3. If `scripts/` created, add a placeholder script with appropriate shebang
4. If `assets/` created, add a README explaining what assets to add

### Step 7: Confirm

Report success:
> "Created skill 'SKILL_NAME':
>
> Claude: ~/.claude/skills/SKILL_NAME/
> - SKILL.md (1024 char description limit)
> [- references/ if created]
>
> Codex: ~/.codex/skills/SKILL_NAME/
> - SKILL.md (500 char description limit)
> [- references/ if created]
>
> The skill will be available after restarting Claude Code and Codex."

## Examples

**User input:** "Create a code-review skill that analyzes PRs for security issues"
- Name: code-review
- Description: "Analyzes code and pull requests for security vulnerabilities, best practice violations, and potential bugs. Use when reviewing code changes or auditing security."
- Recommended structure: SKILL.md + references/ (for security guidelines)

**User input:** "Create a deploy skill that runs our deployment scripts"
- Name: deploy
- Description: "Executes deployment workflows and scripts. Use when deploying applications or running release processes."
- Recommended structure: SKILL.md + scripts/ (for deployment automation)

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md
- references/codex-formats.md
