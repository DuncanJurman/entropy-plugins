# Ralph-Ready Bead Specification

This document defines the bead format for god-ralph execution.

## Standard Bead Fields

These are the core beads fields:

```yaml
id: beads-abc123          # Auto-generated
title: "Add user API"     # Required, clear and actionable
description: |            # Required, detailed
  Implement GET /api/users endpoint that returns
  paginated user list with filtering support.
type: feature             # feature, task, bug, epic
priority: 2               # 0-4 (0=critical, 4=backlog)
status: open              # open, in_progress, blocked, closed
assignee: null            # Optional, username
```

## Ralph-Specific Fields (ralph_spec)

These fields tell Ralph how to execute the bead.

### completion_promise
String that Ralph outputs when truly complete.

```yaml
completion_promise: "BEAD COMPLETE"
```

Ralph outputs: `<promise>BEAD COMPLETE</promise>`

**Rules:**
- Only output when ALL acceptance criteria met
- Never lie to escape the loop
- Case-sensitive exact match

### max_iterations
Safety limit for iterations.

```yaml
max_iterations: 50
```

**Guidelines:**
- Simple task: 20
- Medium task: 50 (default)
- Complex task: 100

### acceptance_criteria
List of checks that must pass for completion.

```yaml
acceptance_criteria:
  - type: test
    command: "npm test -- --grep 'users'"
  - type: lint
    command: "npm run lint"
  - type: build
    command: "npm run build"
```

## Acceptance Criteria Types

### test
Run a test command, check exit code.

```yaml
- type: test
  command: "npm test"
```

### lint
Run linter, no errors allowed.

```yaml
- type: lint
  command: "npm run lint"
```

### build
Run build, must succeed.

```yaml
- type: build
  command: "npm run build"
```

### api
Check API endpoint response.

```yaml
- type: api
  check: "GET /api/users returns 200"
  preview_url: true  # Use Vercel/Railway preview
```

### ui
Visual verification via Chrome extension.

```yaml
- type: ui
  check: "Settings page renders form with 3 fields"
  using: chrome_extension
```

### manual
Requires human verification.

```yaml
- type: manual
  check: "Design matches Figma mockup"
```

## Complete Example

```yaml
title: "Add user settings API endpoint"
description: |
  Implement GET and POST /api/settings endpoints.

  GET: Return user's current settings
  POST: Update settings with validation

  Settings schema:
  - theme: "light" | "dark"
  - notifications: boolean
  - language: string (ISO 639-1)
type: feature
priority: 2

ralph_spec:
  completion_promise: "SETTINGS API COMPLETE"
  max_iterations: 30
  acceptance_criteria:
    - type: test
      command: "npm test -- --grep 'settings'"
    - type: lint
      command: "npm run lint src/api/settings.ts"
    - type: api
      check: "GET /api/settings returns valid JSON"
      preview_url: true
    - type: build
      command: "npm run build"
```

## Storing ralph_spec

Until beads schema is extended, store ralph_spec in comments:

```bash
bd comments beads-abc --add "ralph_spec:
completion_promise: BEAD COMPLETE
max_iterations: 50
acceptance_criteria:
  - type: test
    command: npm test"
```

## Granularity Guidelines

### Too Large
```yaml
title: "Implement user authentication system"
# Too many moving parts, unclear completion
```

### Just Right
```yaml
title: "Add JWT token validation middleware"
# Focused, clear acceptance criteria
```

### Too Small
```yaml
title: "Fix typo in error message"
# Trivial, not worth Ralph overhead
```

## Dependency Patterns

### Sequential Chain
```
Database Schema (beads-001)
    ↓
API Endpoints (beads-002) [depends on beads-001]
    ↓
Frontend UI (beads-003) [depends on beads-002]
```

### Fan-out
```
Core Library (beads-001)
    ↓
├── Service A (beads-002) [depends on beads-001]
├── Service B (beads-003) [depends on beads-001]
└── Service C (beads-004) [depends on beads-001]
```

### Epic Pattern
```
Feature Epic (beads-001) [type: epic]
    │
    ├── Task 1 (beads-002)
    ├── Task 2 (beads-003)
    └── Task 3 (beads-004)
    │
Epic depends on all tasks (reversed from normal)
```
