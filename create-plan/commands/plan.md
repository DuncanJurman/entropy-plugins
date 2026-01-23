---
description: Create a comprehensive implementation plan with codebase exploration, research, and iterative clarification
allowed-tools: ["Read", "Write", "Grep", "Glob", "Bash", "TodoWrite", "AskUserQuestion", "Task", "Skill"]
---

# Create Plan

**Before proceeding, load the `create-plan` skill using the Skill tool.**

The skill contains the complete workflow, plan template, and clarification guide. Follow its instructions to create a comprehensive implementation plan for: $ARGUMENTS

Requirements:
- Ask at least 3 rounds of clarification questions before drafting the plan, unless the user explicitly opts out.
- Do not present the plan until the clarification loop is complete.
- Follow the template exactly and save to `.plans/<topic>.md`.

If no topic provided, ask the user what they want to plan.
