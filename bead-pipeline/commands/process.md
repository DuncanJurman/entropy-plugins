---
description: Process a plan file through the full bead pipeline (decompose -> validate -> validate). Use when transforming implementation plans into validated, self-contained beads ready for multi-agent execution.
---

# Bead Pipeline Process

Transform a plan file into validated, self-contained beads through a three-stage pipeline:

1. **Decomposition**: Break the plan into atomic beads with epics and dependencies
2. **Validation Pass 1**: Validate self-containment, coverage, and dependencies
3. **Validation Pass 2**: Second validation pass on updated beads

## Input

`$ARGUMENTS` should be the path to a plan file (e.g., `.plans/feature-auth.md`)

## Workflow

### Step 1: Validate Inputs

First, verify the plan file exists. Use the Read tool to check if the plan file at `$ARGUMENTS` exists.

If the plan file is not found:
- Report error: "Plan file not found at: $ARGUMENTS"
- Stop the pipeline

### Step 2: Initialize Beads System (if needed)

Check if the beads system is initialized:

```bash
br list --json 2>/dev/null || br init
```

If `br list` fails, run `br init` to initialize the beads system.

### Step 3: Run Decomposition

Use the Task tool to spawn the decompose-agent subagent:

```
Task(
  subagent_type="bead-pipeline:decompose-agent",
  model="opus",
  description="Decompose plan into beads",
  prompt="Decompose the plan file at: $ARGUMENTS

Your task:
1. Read and understand the ENTIRE plan file
2. Identify natural boundaries in the work (files, concerns, dependencies)
3. Determine appropriate granularity for beads
4. Create atomic beads using `br create` commands
5. Establish dependencies using `br dep add` commands
6. Create epics to group related beads (with correct dependency direction: epic depends on children)
7. Write the decomposition log to .beads/decomposition-logs/

CRITICAL: Use `br` commands exclusively (not `bd`).

Return the path to the decomposition log when complete."
)
```

Capture the decomposition log path from the agent's response.

### Step 4: Run Validation Pass 1

Use the Task tool to spawn the validate-agent subagent:

```
Task(
  subagent_type="bead-pipeline:validate-agent",
  model="opus",
  description="Validate beads (pass 1)",
  prompt="Validate the beads created from plan: $ARGUMENTS

Read the decomposition log at: <decomposition-log-path-from-step-3>

Perform these validation checks:
1. **Self-containment**: Every bead must pass the 'future self' test
2. **Spec coverage**: Every requirement in the plan must be covered
3. **Orphan detection**: Every bead must trace to a spec requirement
4. **Dependency validity**: No cycles, correct epic direction

For each issue found:
- Auto-fix if confident (update descriptions, add dependencies)
- If a bead lacks sufficient specification for a future developer to execute perfectly, use the AskUserQuestion tool to gather the missing information

CRITICAL:
- Use `br` commands exclusively (not `bd`)
- Update the decomposition log with all changes made

Return a summary of issues found and fixed."
)
```

### Step 5: Run Validation Pass 2

Use the Task tool to spawn the validate-agent subagent again:

```
Task(
  subagent_type="bead-pipeline:validate-agent",
  model="opus",
  description="Validate beads (pass 2)",
  prompt="Validate the beads from plan: $ARGUMENTS

Read the decomposition log at: <decomposition-log-path-from-step-3>

This is the second validation pass. The beads may have been updated since decomposition.

Perform these validation checks:
1. **Self-containment**: Every bead must pass the 'future self' test
2. **Spec coverage**: Every requirement in the plan must be covered
3. **Orphan detection**: Every bead must trace to a spec requirement
4. **Dependency validity**: No cycles, correct epic direction

For each issue found:
- Auto-fix if confident (update descriptions, add dependencies)
- If a bead lacks sufficient specification for a future developer to execute perfectly, use the AskUserQuestion tool to gather the missing information

CRITICAL:
- Use `br` commands exclusively (not `bd`)
- Update the decomposition log with all changes made

Return a summary of issues found and fixed."
)
```

### Step 6: Generate Summary Report

After all stages complete, output a summary report:

```markdown
## Bead Pipeline Complete

**Plan processed**: $ARGUMENTS
**Decomposition log**: <path>

### Summary

| Stage | Status | Details |
|-------|--------|---------|
| Decomposition | Complete | X beads, Y epics created |
| Validation Pass 1 | Complete | A issues found, B fixed |
| Validation Pass 2 | Complete | C issues found, D fixed |

### Beads Ready for Work

List beads with status READY (no blockers):
- br-XXX: Title
- br-YYY: Title

### Beads Blocked

List beads with blockers:
- br-ZZZ: Title (blocked by: br-XXX)

### Next Steps

1. Run `br list --status=open` to see all beads
2. Run `bv` to visualize the dependency graph
3. Pick a ready bead and start implementation
```

## Error Handling

- **Plan file not found**: Stop and report the error
- **br init needed**: Auto-run `br init` and continue
- **Decomposition fails**: Stop and report what failed
- **Validation asks questions**: Use AskUserQuestion, then continue
- **br commands fail**: Report the error with command output

## Model Invocation

This command should also be invoked automatically by Claude when:
- Processing a large implementation plan that needs decomposition
- User asks to "decompose this plan" or "create beads from this plan"
- Preparing work for multi-agent execution
