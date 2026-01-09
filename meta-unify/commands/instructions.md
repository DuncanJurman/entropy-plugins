---
description: Manage CLAUDE.md and AGENTS.md instruction files for both systems
---

# Instructions Command

You are helping the user manage custom instructions for both Claude Code (CLAUDE.md) and Codex (AGENTS.md).

## Arguments Parsing

Parse `$ARGUMENTS` for:
- **Content to add**: New instructions, sections, or guidelines
- **Section name**: Which section to add/update (optional)

## Flags

Check for these flags in `$ARGUMENTS`:
- `--claude-only`: Only update CLAUDE.md
- `--codex-only`: Only update AGENTS.md
- `--project`: Use project scope instead of user scope

## Special Sections

These section headers have special behavior:

- `## Claude Only` - Content ONLY written to CLAUDE.md, excluded from AGENTS.md
- `## Codex Only` - Content ONLY written to AGENTS.md, excluded from CLAUDE.md

All other sections are written to BOTH files.

## Flow

### Step 1: Determine Target Files

**User Scope (default):**
- Claude: `~/.claude/CLAUDE.md`
- Codex: `~/.codex/AGENTS.md`

**Project Scope (--project flag):**
- Claude: `.claude/CLAUDE.md`
- Codex: `AGENTS.md` (at repository root)

### Step 2: Read Existing Files

Read both files if they exist. Parse markdown headers to identify sections:
```
## Section Name
Content...

## Another Section
More content...
```

### Step 3: Gather Content

If user provided content in `$ARGUMENTS`, proceed.

Otherwise, ask:
> "What instructions would you like to add?
>
> You can:
> - Add a new section with a `## Header`
> - Add content to an existing section
> - Use `## Claude Only` for Claude-specific instructions
> - Use `## Codex Only` for Codex-specific instructions"

### Step 4: Merge Logic

**For matching section headers:**
1. Find section in existing file
2. Append new content to that section
3. Preserve existing content

**For new sections:**
1. Append new section at end of file

**For special sections:**
- `## Claude Only` → Only add to CLAUDE.md
- `## Codex Only` → Only add to AGENTS.md
- All others → Add to both files

### Step 5: Generate Content

Structure the output appropriately:

**Example merged CLAUDE.md:**
```markdown
# Project Instructions

## Coding Standards
[existing content]
[new content appended]

## Claude Only
These instructions are specific to Claude Code and won't appear in AGENTS.md.

## Testing Guidelines
[content for both systems]
```

**Example merged AGENTS.md:**
```markdown
# Project Instructions

## Coding Standards
[existing content]
[new content appended]

## Codex Only
These instructions are specific to Codex and won't appear in CLAUDE.md.

## Testing Guidelines
[content for both systems]
```

### Step 6: Write Files

1. Backup existing files
2. Write updated content
3. Ensure proper markdown formatting

### Step 7: Confirm

> "Updated instructions:
>
> **CLAUDE.md** (~/.claude/CLAUDE.md):
> - Added section: ## Error Handling
> - Updated section: ## Coding Standards
>
> **AGENTS.md** (~/.codex/AGENTS.md):
> - Added section: ## Error Handling
> - Updated section: ## Coding Standards
>
> Sections excluded from cross-sync:
> - '## Claude Only' (CLAUDE.md only)
> - '## Codex Only' (AGENTS.md only)
>
> Instructions will apply on next session."

## Examples

**User input:** "/meta-unify:instructions Add a section about error handling best practices"
- Creates new `## Error Handling` section in both files

**User input:** "/meta-unify:instructions --project Add ## Claude Only section about using specific Claude tools"
- Creates `## Claude Only` section only in `.claude/CLAUDE.md`
- Does NOT add to AGENTS.md

**User input:** "/meta-unify:instructions Update the Testing section with new requirements"
- Finds existing `## Testing` section
- Appends new content to that section in both files

## File Format Notes

**CLAUDE.md structure:**
```markdown
# [Project Name] Instructions

## Section 1
Content...

## Claude Only
Claude-specific content...
```

**AGENTS.md structure:**
```markdown
# [Project Name] Instructions

## Section 1
Content...

## Codex Only
Codex-specific content...
```

**Codex override files:**
- `AGENTS.override.md` takes precedence over `AGENTS.md` in Codex
- This command manages `AGENTS.md`, not override files

## Reference

For complete format specifications, invoke the meta-unify-core skill to access:
- references/claude-formats.md (CLAUDE.md section)
- references/codex-formats.md (AGENTS.md section)
