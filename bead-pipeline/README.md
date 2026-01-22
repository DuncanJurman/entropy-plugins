# Bead Pipeline Plugin

Automated pipeline for decomposing implementation plans into validated, self-contained beads ready for multi-agent execution.

## Overview

This plugin chains three stages to transform plans into production-ready beads:

1. **Decomposition** - Transforms plans into atomic beads with epics and dependencies
2. **Validation Pass 1** - Validates self-containment, coverage, and dependencies
3. **Validation Pass 2** - Second validation on updated beads for quality assurance

## Installation

```bash
claude plugin install bead-pipeline@entropy-plugins
```

Or for local development:

```bash
claude --plugin-dir ./bead-pipeline
```

## Usage

### User Invocation

```bash
/bead-pipeline:process .plans/my-feature.md
```

### Model Invocation

Claude will automatically use this plugin when:
- Processing large implementation plans that need decomposition
- Asked to "decompose this plan" or "create beads from this plan"
- Preparing work for multi-agent execution

## Requirements

- **Beads system** (`br` CLI) must be installed
- Plan file in Markdown format
- `bv` (beads viewer) for structural analysis

## How It Works

### Pipeline Flow

```
┌─────────────────┐
│   Plan File     │
│ (.plans/*.md)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Decompose Agent │ ──── Creates beads (br create)
│   (opus model)  │ ──── Establishes deps (br dep add)
└────────┬────────┘ ──── Writes decomposition log
         │
         ▼
┌─────────────────┐
│ Validate Agent  │ ──── Checks self-containment
│  (Pass 1)       │ ──── Checks coverage
│   (opus model)  │ ──── Checks dependencies
└────────┬────────┘ ──── Updates decomposition log
         │
         ▼
┌─────────────────┐
│ Validate Agent  │ ──── Second validation pass
│  (Pass 2)       │ ──── Works on updated beads
│   (opus model)  │ ──── Final quality gate
└────────┬────────┘ ──── Updates decomposition log
         │
         ▼
┌─────────────────┐
│ Summary Report  │
└─────────────────┘
```

### Decomposition Stage

The decompose agent:
- Analyzes the full plan to understand scope and requirements
- Identifies natural boundaries in the work
- Creates atomic beads with self-contained descriptions
- Establishes dependencies between beads
- Creates epics to group related work
- Writes a decomposition log to `.beads/decomposition-logs/`

### Validation Stages

Each validation pass:
1. **Self-Containment Check** - Ensures each bead has Task + Acceptance Criteria
2. **Spec Coverage Check** - Ensures every plan requirement has a bead
3. **Orphan Detection** - Flags beads that don't trace to requirements
4. **Dependency Validity** - Checks for cycles and correct epic direction

When a bead lacks sufficient detail, the validator uses `AskUserQuestion` to gather missing specifications.

## Output

### Decomposition Log

Located at `.beads/decomposition-logs/<timestamp>-<plan-name>.md`:

```markdown
# Decomposition: my-feature

**Source:** .plans/my-feature.md
**Created:** 2026-01-22T12:34:56Z
**Total beads created:** 8
**Epics:** 2
**Tasks:** 6

## All Beads

| ID | Title | Type | Priority | Blocked By | Status |
|----|-------|------|----------|------------|--------|
| br-101 | Setup middleware | task | 0 | - | READY |
| br-102 | Add endpoint | task | 1 | br-101 | blocked |
...
```

### Summary Report

After completion, you'll see:
- Plan file processed
- Number of beads/epics created
- Validation issues found and fixed
- Ready beads (no blockers)
- Blocked beads (with their blockers)

## Plugin Components

### Commands

| Command | Description |
|---------|-------------|
| `/bead-pipeline:process` | Run the full pipeline on a plan file |

### Agents

| Agent | Purpose |
|-------|---------|
| `decompose-agent` | Transforms plans into atomic beads |
| `validate-agent` | Validates bead quality and coverage |

### Skills

| Skill | Purpose |
|-------|---------|
| `decompose-plan` | Instructions for plan decomposition |
| `validate-beads` | Instructions for bead validation |

## Error Handling

- **Plan file not found**: Stops and reports the error
- **Beads not initialized**: Auto-runs `br init` and continues
- **Unclear specifications**: Validator asks user for clarification
- **Command failures**: Reports with full error output

## Best Practices

1. **Write detailed plans** - More detail = better beads
2. **Include acceptance criteria** - Makes validation easier
3. **Specify file locations** - Helps agents distribute context
4. **Review the summary** - Check ready vs blocked beads before starting

## Related Tools

- `br` - Bead rust CLI for bead operations
- `bv` - Beads viewer for visualization and analysis
- `decompose-plan` skill - Standalone decomposition
- `validate-beads` skill - Standalone validation

## Contributing

Issues and improvements welcome at the entropy-plugins repository.

## License

MIT
