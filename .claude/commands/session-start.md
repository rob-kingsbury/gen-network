---
name: session-start
description: Initialize a new work session by loading context, checking issues, and confirming readiness.
---

# Session Start Skill

Run this at the beginning of every work session to ensure proper context loading.

## Instructions for Claude

When this skill is invoked:

1. Read the following files in parallel:
   - `.claude/context.md`
   - `HANDOFF.md` (if exists)
   - `.claude/rules/development-workflow.md` (if exists)

2. Run: `gh issue list --state open --limit 10`

3. Extract from context.md:
   - `project:` field (project name)
   - `continue_with:` field (next priority)
   - `last_session:` field (session number)

4. Output in this format:
   ```
   [Project Name] ready. [X] open issues. Priority: [continue_with value]
   Session: [last_session + 1]
   Files loaded: [list of files read]

   Open Issues:
   #XX - Title [label]
   ...
   ```

5. If any critical files are missing, warn the user but don't fail.

## Never Skip This

**DO NOT begin work without running session-start.** Context drift causes wasted effort.
