---
description: Interactive wizard to create Ralph-ready beads with acceptance criteria. Requires initial context describing the feature or task.
---

# /god-ralph plan <initial context>

Interactive wizard to create well-specified, Ralph-ready beads with enough context for autonomous execution.

## Usage

```bash
# Simple idea
/god-ralph plan I want to add user authentication with JWT

# Detailed context
/god-ralph plan Add a dark mode toggle to settings. Should persist to localStorage and apply a .dark class to body

# Multi-line context
/god-ralph plan Build a notification system that:
- Sends email and push notifications
- Has user preferences for each type
- Queues notifications for batch sending
```

## Required: Initial Context

**The user MUST provide initial context.** If they run `/god-ralph plan` without any description, prompt them:

```
Please provide the initial context for your plan. Describe what you want to build:

/god-ralph plan <describe your feature or task here>

Examples:
- /god-ralph plan Add user authentication with JWT and password reset
- /god-ralph plan Fix the checkout bug where totals don't update
- /god-ralph plan Refactor the API to use async/await instead of callbacks
```

**Do NOT proceed with generic questions.** Wait for the user to provide their idea.

## Visual References (Screenshots, Mockups)

When the user provides images (mockups, screenshots, designs):

1. **Claude cannot save pasted images** - ask user to save it:
   ```
   Please save that image to: reference-images/<descriptive-name>.png
   ```

2. **Verify and view it:**
   ```bash
   mkdir -p reference-images
   Read("reference-images/homepage-mockup.png")
   ```

3. **Include in bead description** with path + text summary:
   ```markdown
   ## Visual References
   - `reference-images/homepage-mockup.png` - Hero with gradient, 3 feature cards, dark footer
   ```

Ralph workers can use the Read tool to view images, so they'll have full visual context.

## Philosophy

Each bead should be **self-contained** enough that Ralph can start working immediately without wasting iterations on exploration. But don't over-specify - Ralph should still have room to make implementation decisions.

**Balance:**
- ✓ Key files to modify and reference
- ✓ Relevant patterns to follow
- ✓ Clear acceptance criteria
- ✗ Exhaustive file listings
- ✗ Step-by-step implementation details
- ✗ Every convention in the codebase

## Handling Initial Context

When the user provides initial context with the command:

1. **Parse the initial idea** - Extract key information:
   - What feature/task is being requested?
   - Are there any constraints mentioned?
   - Are there technology choices specified?
   - Any files or locations mentioned?

2. **Acknowledge what you understood** - Show the user what you extracted:
   ```
   I understand you want to:
   - Add user authentication
   - Use JWT tokens
   - Need login/register endpoints

   Let me ask some follow-up questions to fill in the gaps...
   ```

3. **Ask ONLY what's missing** - Don't re-ask things already specified:
   - Focus on gaps and ambiguities

## Wizard Phases

### Phase 1: Clarify

**Starting from user's initial context:**

1. Parse and acknowledge what was understood
2. Use `AskUserQuestion` to fill in gaps only
3. Ask targeted follow-ups based on what's missing, continue iterating the plan, refining, and asking follow up question until nothing in the plan is uncertain/unclear

**Core questions to answer (skip if already provided in initial context):**
- What is the goal? *(usually provided)*
- What are the constraints?
- What existing code is involved?
- What are the success criteria?
- Are there dependencies on other work?
- What tests need to pass?

**Smart follow-up strategy:**
- Group related questions (don't ask 10 one at a time)
- Use multiple choice when options are clear
- Let user provide freeform for open questions
- Stop asking when implementation is clear enough
- **Never re-ask what the user already specified**

Continue asking follow-up questions based on answers until implementation details are clear.

### Phase 2: Explore

**Auto-explore the codebase** to gather context, then confirm with user:

```bash
# Find relevant files
Glob("src/**/*auth*")
Glob("src/**/*user*")

# Search for patterns
Grep("login", type="ts")
Grep("JWT", type="ts")

# Read key files
Read("src/api/routes.ts")
Read("src/middleware/auth.ts")
```

**Present findings to user:**
```
I found these relevant files:
- src/api/auth.ts (existing auth routes)
- src/middleware/jwt.ts (JWT validation)
- src/models/User.ts (user model)
- tests/auth.test.ts (test patterns)

Is this correct? Any files I missed?
```

### Phase 3: Decompose

Break the feature into granular beads:

- Each bead should be completable in 5-15 iterations
- Identify dependencies between beads
- Order beads by dependency graph
- Group parallelizable beads

### Phase 4: Specify

For each bead, create a **rich description with sections**:

```markdown
## Task
[Clear statement of what needs to be done]

## Context
[Why this task exists, how it fits into the larger feature]

## Key Files
- `src/api/auth.ts` - Add new endpoint here
- `src/middleware/jwt.ts` - Reference for token validation pattern
- `src/models/User.ts` - User model with password field

## Patterns to Follow
[Show 1-2 relevant code snippets from the codebase]

Example from existing endpoint:
\`\`\`typescript
router.post('/login', validateBody(loginSchema), async (req, res) => {
  // ... existing pattern
});
\`\`\`

## Acceptance Criteria
- [ ] POST /api/auth/register creates new user
- [ ] Returns 400 for invalid email format
- [ ] Returns 409 if email already exists
- [ ] All tests in tests/auth.test.ts pass
- [ ] No lint errors

## Notes
[Any edge cases, gotchas, or decisions left to Ralph]
```

## Bead Creation

Create beads with the rich description:

```bash
bd create \
  --title="Implement user registration endpoint" \
  --type=feature \
  --priority=2 \
  --description="## Task
Add POST /api/auth/register endpoint.

## Context
Part of authentication feature. Users need to create accounts before logging in.

## Key Files
- src/api/auth.ts - Add endpoint here
- src/models/User.ts - User model
- src/utils/password.ts - Password hashing (use bcrypt pattern)

## Patterns to Follow
Follow existing POST endpoint pattern in src/api/users.ts

## Acceptance Criteria
- POST /api/auth/register works
- Validates email format
- Hashes password before storing
- Returns JWT on success
- Tests pass: npm test -- --grep register

## Notes
- Use existing validateBody middleware
- Email should be case-insensitive"

# Add ralph_spec
bd comments <bead-id> --add "ralph_spec:
completion_promise: BEAD COMPLETE
max_iterations: 50
acceptance_criteria:
  - type: test
    command: npm test -- --grep register
  - type: lint
    command: npm run lint"

# Add dependencies
bd dep add <child-bead> <parent-bead>
```

## Example Sessions

### Missing Context (Prompt User)

```
User: /god-ralph plan

Wizard: Please provide the initial context for your plan. Describe what you want to build:

/god-ralph plan <describe your feature or task here>

Examples:
- /god-ralph plan Add user authentication with JWT and password reset
- /god-ralph plan Fix the checkout bug where totals don't update
- /god-ralph plan Refactor the API to use async/await instead of callbacks
```

### Standard Flow (With Context)

```
User: /god-ralph plan Add JWT auth with email/password login and registration

Wizard: I understand you want to:
- Add authentication system
- Use JWT tokens
- Email/password login and registration

Let me ask a few follow-up questions to fill in the gaps...

[AskUserQuestion with 2 questions:]
Q1: Do you need password reset functionality?
Q2: Should users verify their email before logging in?

User answers: Yes to reset, No to email verification

Wizard: Got it. Let me explore your codebase...

[Runs Glob and Grep to find relevant files]

I found:
- src/api/ contains your API routes
- src/models/User.ts exists with email field
- No existing auth middleware
- src/utils/email.ts for sending emails
- Tests use Jest with supertest

Does this look right? Any files I missed?

User: Looks good

Wizard: Based on exploration, here are the beads I'll create:

---

**Bead 1: Add JWT middleware**
- Files: src/middleware/auth.ts (new), src/types/express.d.ts
- Pattern: Follow src/middleware/logger.ts structure
- Criteria: Middleware validates JWT, attaches user to req

**Bead 2: Implement registration**
- Files: src/api/auth.ts (new), src/models/User.ts
- Pattern: Follow src/api/users.ts POST pattern
- Depends on: Bead 1
- Criteria: Creates user, returns JWT

**Bead 3: Implement login**
- Files: src/api/auth.ts
- Pattern: Compare password with bcrypt
- Depends on: Bead 1
- Criteria: Returns JWT for valid credentials

**Bead 4: Add password reset**
- Files: src/api/auth.ts, src/utils/email.ts
- Pattern: Use existing email utility
- Depends on: Bead 2, Bead 3
- Criteria: Sends reset email, token works

Create these beads? [y/n]
```

## Guidelines

### What to Include in Context

**Do include:**
- Specific file paths to modify
- 1-2 code snippets showing patterns to follow
- Key dependencies/imports needed
- Existing test patterns
- Non-obvious constraints

**Don't include:**
- Every file in the codebase
- Step-by-step implementation
- Full file contents
- Generic coding advice

### Good Bead Granularity
- "Add login endpoint with validation" ✓
- "Implement authentication system" ✗ (too large)
- "Fix typo in login error message" ✗ (too small)

### Acceptance Criteria
- Specific, runnable commands
- Clear pass/fail determination
- Include both happy path and key edge cases

## References

- [BEAD_SPEC.md](../skills/god-ralph/references/BEAD_SPEC.md) - Ralph-ready bead format specification
- [WORKFLOWS.md](../skills/god-ralph/references/WORKFLOWS.md) - Common workflow patterns

## Notes

- The wizard creates beads but doesn't execute them
- Use `/god-ralph start` to begin execution
- Beads are stored via the standard `bd` CLI
- Rich description gives Ralph context without over-constraining
- Ralph can still explore and make implementation decisions
