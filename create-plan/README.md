# Create Plan Plugin

A Claude Code plugin for creating comprehensive, self-contained implementation plans through iterative exploration, research, and clarification.

## Installation

Add this plugin to Claude Code:

```bash
claude plugins add ./create-plan
```

Or for development/testing:

```bash
claude --plugin-dir ./create-plan
```

## Usage

### Slash Command

Invoke directly with a topic:

```
/create-plan:plan API rate limiting
```

Or invoke without arguments to be prompted:

```
/create-plan:plan
```

### Auto-Invocation

The skill automatically activates when you ask things like:

- "Create a plan for adding user authentication"
- "Design a caching system for the API"
- "How should I implement the search feature?"
- "Architect a solution for real-time notifications"
- "Plan the implementation of dark mode"

## What It Does

1. **Explores your codebase** - Launches parallel agents to understand existing patterns and architecture
2. **Clarifies requirements** - Asks structured questions (minimum 3 rounds) to understand scope, design decisions, and implementation preferences
3. **Presents options** - When multiple approaches exist, shows pros/cons for each
4. **Generates comprehensive plan** - Creates a self-contained document another developer could execute
5. **Saves to `.plans/`** - Automatically saves the plan with an auto-generated filename

## Files

```
create-plan/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── plan.md               # /create-plan:plan command
├── skills/
│   └── create-plan/
│       ├── SKILL.md          # Full skill definition
│       └── references/
│           ├── plan-template.md
│           └── clarification-guide.md
└── README.md
```

## Output

Plans are saved to `.plans/<topic-name>.md` in your project directory, following a structured template that includes:

- Overview and context
- Design decisions with rationale
- Step-by-step implementation details
- Files to create/modify
- Verification and acceptance criteria
- Exploration findings
